"""Today's and tomorrow's events from a calendar's private iCal address."""

from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

import aiohttp
import icalendar
import recurring_ical_events


async def fetch(session: aiohttp.ClientSession, url: str) -> bytes:
    async with session.get(url, timeout=aiohttp.ClientTimeout(total=30)) as r:
        r.raise_for_status()
        return await r.read()


def _local(value, tz: ZoneInfo) -> tuple[datetime, bool]:
    """An event boundary as local time, plus whether it's an all-day date."""
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=tz), False
        return value.astimezone(tz), False
    return datetime.combine(value, time.min, tz), True


def events(ics: bytes, now: datetime) -> dict:
    """Events still to come (or in progress) today, tomorrow's, and the first one after that
    within two months. `now` is aware local time."""
    tz = now.tzinfo
    cal = icalendar.Calendar.from_ical(ics)
    today = now.date()
    start = datetime.combine(today, time.min, tz)
    end = start + timedelta(days=60)

    items = []
    for ev in recurring_ical_events.of(cal).between(start, end):
        if str(ev.get("STATUS", "")).upper() == "CANCELLED":
            continue
        begin, all_day = _local(ev.get("DTSTART").dt, tz)
        finish_raw = ev.get("DTEND")
        if finish_raw is not None:
            finish, _ = _local(finish_raw.dt, tz)
        else:
            finish = begin + (timedelta(days=1) if all_day else timedelta(0))
        items.append({
            "title": str(ev.get("SUMMARY", "Untitled")).strip(),
            "location": str(ev.get("LOCATION", "")).split(",")[0].strip(),
            "start": begin,
            "end": finish,
            "all_day": all_day,
        })
    items.sort(key=lambda e: (not e["all_day"], e["start"]))

    tomorrow = today + timedelta(days=1)
    todays = [e for e in items if e["start"].date() <= today and e["end"] > now]
    tomorrows = [e for e in items if e["start"].date() == tomorrow]
    later = [e for e in items if e["start"].date() > tomorrow]
    later.sort(key=lambda e: e["start"])
    return {"today": todays, "tomorrow": tomorrows, "next": later[0] if later else None}
