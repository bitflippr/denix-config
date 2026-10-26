import tomllib
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Host:
    name: str  # shown on the panel
    # Tailscale node names (the first label of the MagicDNS name) this tile covers. Several
    # entries share one tile when they are different OS installs on the same machine.
    nodes: list[dict]  # {"node": "desktop-1od2lvu", "os": "Windows", "ssh": "windows", "kind": "windows"}


@dataclass
class Config:
    listen_host: str
    listen_port: int
    timezone: str
    state_dir: Path
    latitude: float
    longitude: float
    calendar_url_file: Path | None
    hosts: list[Host] = field(default_factory=list)
    rotate_minutes: int = 5
    fetch_minutes: int = 15


def load(path: str) -> Config:
    raw = tomllib.loads(Path(path).read_text())
    host, _, port = raw.get("listen", "0.0.0.0:8737").rpartition(":")
    cal = raw.get("calendar", {}).get("ics_url_file")
    return Config(
        listen_host=host,
        listen_port=int(port),
        timezone=raw["timezone"],
        state_dir=Path(raw.get("state_dir", "state")),
        latitude=raw["weather"]["latitude"],
        longitude=raw["weather"]["longitude"],
        calendar_url_file=Path(cal) if cal else None,
        hosts=[Host(h["name"], h["nodes"]) for h in raw.get("fleet", {}).get("hosts", [])],
        rotate_minutes=raw.get("rotate_minutes", 5),
        fetch_minutes=raw.get("fetch_minutes", 15),
    )
