"""HTML templates -> 800x480 1-bit PNGs, via headless Chromium."""

import hashlib
import io
from pathlib import Path

import jinja2
from PIL import Image
from playwright.async_api import async_playwright

HERE = Path(__file__).parent
STATIC = HERE.parent / "static"
WIDTH, HEIGHT = 800, 480
THRESHOLD = 150  # grey levels below this become black; a little bias keeps thin strokes intact


def _icon(name: str) -> str:
    return (STATIC / "icons" / f"{name}.svg").read_text()


class Renderer:
    def __init__(self):
        self.env = jinja2.Environment(
            loader=jinja2.FileSystemLoader(HERE / "templates"),
            autoescape=jinja2.select_autoescape(["html"]),
        )
        self.env.globals["icon"] = lambda name: jinja2.utils.markupsafe.Markup(_icon(name))
        self._pw = None
        self._browser = None

    async def start(self) -> None:
        self._pw = await async_playwright().start()
        self._browser = await self._pw.chromium.launch()

    async def stop(self) -> None:
        if self._browser:
            await self._browser.close()
        if self._pw:
            await self._pw.stop()

    async def render(self, template: str, **context) -> bytes:
        html = self.env.get_template(template).render(static=STATIC.as_uri(), **context)
        page = await self._browser.new_page(viewport={"width": WIDTH, "height": HEIGHT})
        try:
            await page.set_content(html, wait_until="load")
            await page.evaluate("document.fonts.ready")
            shot = await page.screenshot(type="png")
        finally:
            await page.close()
        grey = Image.open(io.BytesIO(shot)).convert("L")
        mono = grey.point(lambda p: 255 if p >= THRESHOLD else 0).convert("1", dither=Image.Dither.NONE)
        out = io.BytesIO()
        mono.save(out, format="PNG", optimize=True)
        return out.getvalue()


def digest(png: bytes) -> str:
    return hashlib.sha1(png).hexdigest()[:8]
