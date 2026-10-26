"""HTTP server: the clock asks /clock/manifest which panels to show, then downloads any
it doesn't have from /clock/panel/<hash>.png."""

import argparse
import asyncio
import base64
import logging
import time
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import aiohttp
from aiohttp import web

from . import config as config_mod
from .render import STATIC, Renderer, digest
from .sources import calendar, fleet, weather

log = logging.getLogger("trmnl-panels")


def fmt_time(t: datetime, h24: bool) -> str:
    return t.strftime("%H:%M") if h24 else t.strftime("%-I:%M %p")


def fmt_hour(t: datetime, h24: bool, with_period: bool) -> str:
    if h24:
        return t.strftime("%H")
    return t.strftime("%-I %p") if with_period else t.strftime("%-I")


def fmt_bytes(n: float) -> str:
    gb = n / 1e9
    return f"{gb / 1000:.1f} TB" if gb >= 1000 else f"{gb:.0f} GB"


def fmt_since(t: datetime, now: datetime, h24: bool) -> str:
    if t.date() == now.date():
        return fmt_time(t, h24)
    if now - t < timedelta(days=6):
        return t.strftime("%a")
    return t.strftime("%b %-d")


def fmt_uptime(seconds: float) -> str:
    days = int(seconds // 86400)
    if days >= 1:
        return f"{days} day{'s' if days != 1 else ''}"
    hours = int(seconds // 3600)
    return f"{hours}h" if hours else f"{int(seconds // 60)}m"


class Server:
    def __init__(self, cfg: config_mod.Config):
        self.cfg = cfg
        self.tz = ZoneInfo(cfg.timezone)
        cfg.state_dir.mkdir(parents=True, exist_ok=True)
        self.renderer = Renderer()
        self.fleet = fleet.Fleet(cfg.hosts, cfg.state_dir / "fleet.json")
        self.weather_raw = None
        self.calendar_ics = None
        self.images: dict[str, bytes] = {}
        self.font_b64 = base64.b64encode((STATIC / "fonts" / "InterTight.ttf").read_bytes()).decode()

    # ---- data refresh -------------------------------------------------------------

    async def _every(self, seconds: int, name: str, fn):
        while True:
            try:
                await fn()
            except Exception as e:  # keep the last good data; try again next round
                log.warning("%s refresh failed: %s", name, e)
            await asyncio.sleep(seconds)

    async def _weather(self):
        self.weather_raw = await weather.fetch(self.http, self.cfg.latitude, self.cfg.longitude, self.cfg.timezone)

    async def _calendar(self):
        url = self.cfg.calendar_url_file.read_text().strip()
        self.calendar_ics = await calendar.fetch(self.http, url)

    async def start(self, app):
        self.http = aiohttp.ClientSession()
        await self.renderer.start()
        self.tasks = [
            asyncio.create_task(self._every(15 * 60, "weather", self._weather)),
            asyncio.create_task(self._every(3 * 60, "fleet", self.fleet.refresh)),
        ]
        if self.cfg.calendar_url_file:
            self.tasks.append(asyncio.create_task(self._every(10 * 60, "calendar", self._calendar)))

    async def stop(self, app):
        for t in self.tasks:
            t.cancel()
        await self.renderer.stop()
        await self.http.close()

    # ---- panels -----------------------------------------------------------------------

    def _weather_summary(self, now):
        return weather.summarize(self.weather_raw, now) if self.weather_raw else None

    def _calendar_panel(self, now, h24):
        if self.calendar_ics is None:
            return None
        data = calendar.events(self.calendar_ics, now)

        def row(e, highlight=False):
            return {"title": e["title"], "time_label": "All day" if e["all_day"] else fmt_time(e["start"], h24),
                    "note": e["location"], "highlight": highlight}

        def when(e):
            day = e["start"].strftime("%a, %b %-d")
            return day if e["all_day"] else f"{day}, {fmt_time(e['start'], h24)}"

        later = data["next"]
        later_line = f"Next: {when(later)} · {later['title']}" if later else "Nothing in the next two months"

        if data["today"]:
            rows, highlighted = [], False
            for e in data["today"]:
                r = row(e)
                if not e["all_day"] and not highlighted:
                    r["highlight"] = highlighted = True
                    r["note"] = "now" if e["start"] <= now else "next"
                rows.append(r)
            rows.sort(key=lambda r: not r["highlight"])  # current or next event first
            tomorrow = data["tomorrow"]
            if tomorrow:
                first = tomorrow[0]
                footer = f"Tomorrow: {'All day' if first['all_day'] else fmt_time(first['start'], h24)} {first['title']}"
                if len(tomorrow) > 1:
                    footer += f" · {len(tomorrow) - 1} more"
            else:
                footer = "Tomorrow: nothing scheduled"
            if len(rows) > 3:
                footer = f"{len(rows) - 3} more today · {footer}"
            return "calendar.html", {"label": "TODAY", "events": rows, "footer": footer}

        if data["tomorrow"]:
            rows = [row(e) for e in data["tomorrow"]]
            footer = f"{len(rows) - 3} more tomorrow" if len(rows) > 3 else "Nothing else today"
            return "calendar.html", {"label": "TOMORROW", "events": rows, "footer": footer}

        return "calendar.html", {"label": "CALENDAR", "events": [], "empty": "Nothing today or tomorrow",
                                 "footer": later_line}

    def _fleet_panel(self, now, h24):
        if not self.fleet.tiles:
            return None
        tiles = []
        for t in self.fleet.tiles:
            s = t["stats"]
            tile = {"name": t["name"], "free": None, "used_frac": None}
            if s:
                tile["free"] = f"{fmt_bytes(s['disk_free'])} free"
                tile["used_frac"] = 1 - s["disk_free"] / s["disk_total"]
            if t["online"]:
                up = t.get("uptime")
                if t["multi"]:
                    tile["status"] = f"{t['os']} · up {fmt_uptime(up)}" if up else t["os"]
                else:
                    tile["status"] = f"Up {fmt_uptime(up)}" if up else "Online"
                tile["detail"] = (f"RAM {s['mem_used'] / 2**30:.0f} / {s['mem_total'] / 2**30:.0f} GB"
                                  if s and up else "")
            else:
                tile["status"] = "Offline"
                seen = t["last_seen"]
                tile["detail"] = f"Since {fmt_since(seen.astimezone(self.tz), now, h24)}" if seen else ""
            tiles.append(tile)
        return "fleet.html", {"label": "FLEET", "tiles": tiles}

    def _weather_panel(self, now, h24, summary):
        if not summary:
            return None
        hours, prev_period = [], None
        for h in summary["hours"]:
            period = h["time"].strftime("%p")
            hours.append({**h, "label": fmt_hour(h["time"], h24, period != prev_period),
                          "bar": 0 if h["precip"] < 10 else max(3, round(h["precip"] * 0.24))})
            prev_period = period
        return "weather.html", {"label": "NEXT 12 HOURS", "hours": hours}

    async def build(self, h24: bool) -> list[str]:
        now = datetime.now(self.tz)
        summary = self._weather_summary(now)
        panels = [p for p in (
            self._calendar_panel(now, h24),
            self._fleet_panel(now, h24),
            self._weather_panel(now, h24, summary),
        ) if p]
        hashes = []
        for i, (template, ctx) in enumerate(panels):
            png = await self.renderer.render(template, weather=summary, index=i, count=len(panels),
                                             font_b64=self.font_b64, **ctx)
            h = digest(png)
            self.images[h] = png
            hashes.append(h)
        # Keep recent images around for clocks that are mid-download
        if len(self.images) > 40:
            for h in list(self.images)[: len(self.images) - 40]:
                del self.images[h]
        return hashes

    # ---- HTTP -------------------------------------------------------------------------

    async def manifest(self, request):
        h24 = request.query.get("h24") == "1"
        mv = request.query.get("mv")
        if mv:
            with open(self.cfg.state_dir / "battery.log", "a") as f:
                f.write(f"{int(time.time())} {mv}\n")
        hashes = await self.build(h24)
        return web.json_response({"rotate": self.cfg.rotate_minutes, "fetch": self.cfg.fetch_minutes,
                                  "panels": hashes})

    async def panel(self, request):
        png = self.images.get(request.match_info["hash"])
        if png is None:
            raise web.HTTPNotFound()
        return web.Response(body=png, content_type="image/png")

    async def preview(self, request):
        """Render one panel by position, for checking designs."""
        hashes = await self.build(request.query.get("h24") == "1")
        i = int(request.match_info["index"])
        if i >= len(hashes):
            raise web.HTTPNotFound()
        return web.Response(body=self.images[hashes[i]], content_type="image/png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    cfg = config_mod.load(args.config)
    server = Server(cfg)
    app = web.Application()
    app.on_startup.append(server.start)
    app.on_cleanup.append(server.stop)
    app.router.add_get("/clock/manifest", server.manifest)
    app.router.add_get("/clock/panel/{hash}.png", server.panel)
    app.router.add_get("/preview/{index}.png", server.preview)
    web.run_app(app, host=cfg.listen_host, port=cfg.listen_port, print=None)
