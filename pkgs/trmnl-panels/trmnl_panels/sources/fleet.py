"""Fleet machines: online state from Tailscale, uptime/disk/RAM over SSH.

The last values read from each machine are kept, so a machine that's asleep still
shows its disk figure."""

import asyncio
import json
import logging
import time
from datetime import datetime
from pathlib import Path

from ..config import Host

PROBE_TIMEOUT = 15

log = logging.getLogger("trmnl-panels")

_LINUX = "cat /proc/uptime; df -B1 --output=size,avail {disk} | tail -1; free -b | awk 'NR==2{{print $2, $7}}'"
_MACOS = (
    "sysctl -n kern.boottime; date +%s; df -k {disk} | tail -1; sysctl -n hw.memsize; "
    "sysctl -n hw.pagesize; vm_stat"
)
_WINDOWS = (
    "$os = Get-CimInstance Win32_OperatingSystem; $d = Get-PSDrive C; "
    "@{ uptime = ((Get-Date) - $os.LastBootUpTime).TotalSeconds; disk_total = $d.Used + $d.Free; "
    "disk_free = $d.Free; mem_total = $os.TotalVisibleMemorySize * 1024; "
    "mem_free = $os.FreePhysicalMemory * 1024 } | ConvertTo-Json -Compress"
)


async def _run(*argv: str) -> str:
    proc = await asyncio.create_subprocess_exec(
        *argv, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL
    )
    try:
        out, _ = await asyncio.wait_for(proc.communicate(), PROBE_TIMEOUT)
    except asyncio.TimeoutError:
        proc.kill()
        raise
    if proc.returncode != 0:
        raise RuntimeError(f"{argv[0]} exited {proc.returncode}")
    return out.decode()


def _ssh(host: str, command: str) -> list[str]:
    return ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", host, command]


async def _probe(node: dict) -> dict | None:
    kind = node.get("kind")
    disk = node.get("disk", "/System/Volumes/Data" if kind == "macos" else "/")
    if kind in ("linux", "local"):
        cmd = _LINUX.format(disk=disk)
        out = await (_run("sh", "-c", cmd) if kind == "local" else _run(*_ssh(node["ssh"], cmd)))
        lines = out.split("\n")
        size, avail = lines[1].split()
        mem_total, mem_avail = lines[2].split()
        return {
            "uptime": float(lines[0].split()[0]),
            "disk_total": int(size), "disk_free": int(avail),
            "mem_total": int(mem_total), "mem_used": int(mem_total) - int(mem_avail),
        }
    if kind == "macos":
        out = (await _run(*_ssh(node["ssh"], _MACOS.format(disk=disk)))).split("\n")
        boot = int(out[0].split("sec = ")[1].split(",")[0])
        cols = out[2].split()
        mem_total, page = int(out[3]), int(out[4])
        stats = {}
        for line in out[5:]:
            if ":" in line:
                k, v = line.split(":", 1)
                stats[k.strip()] = int(v.strip().rstrip(".") or 0) if v.strip().rstrip(".").isdigit() else 0
        used_pages = (stats.get("Pages active", 0) + stats.get("Pages wired down", 0)
                      + stats.get("Pages occupied by compressor", 0))
        return {
            "uptime": int(out[1]) - boot,
            "disk_total": int(cols[1]) * 1024, "disk_free": int(cols[3]) * 1024,
            "mem_total": mem_total, "mem_used": used_pages * page,
        }
    if kind == "windows":
        d = json.loads(await _run(*_ssh(node["ssh"], _WINDOWS)))
        return {
            "uptime": d["uptime"], "disk_total": d["disk_total"], "disk_free": d["disk_free"],
            "mem_total": d["mem_total"], "mem_used": d["mem_total"] - d["mem_free"],
        }
    return None  # no way in; online state only


async def tailscale_nodes() -> dict:
    """Tailscale peers keyed by the first label of their MagicDNS name."""
    status = json.loads(await _run("tailscale", "status", "--json"))
    nodes = {}
    for peer in [status["Self"], *status.get("Peer", {}).values()]:
        name = peer.get("DNSName", "").split(".")[0]
        if not name:
            continue
        seen = peer.get("LastSeen") or ""
        last = None
        if seen and not seen.startswith("0001"):
            last = datetime.fromisoformat(seen.replace("Z", "+00:00"))
        nodes[name] = {"online": bool(peer.get("Online")) or peer is status["Self"], "last_seen": last}
    return nodes


class Fleet:
    def __init__(self, hosts: list[Host], state_file: Path):
        self.hosts = hosts
        self.state_file = state_file
        self.known: dict[str, dict] = {}
        if state_file.exists():
            self.known = json.loads(state_file.read_text())
        self.tiles: list[dict] = []

    async def refresh(self) -> None:
        ts = await tailscale_nodes()
        probes = []
        for host in self.hosts:
            for node in host.nodes:
                if ts.get(node["node"], {}).get("online") and node.get("kind"):
                    probes.append(node)
        results = await asyncio.gather(*(_probe(n) for n in probes), return_exceptions=True)
        for node, result in zip(probes, results):
            if isinstance(result, dict):
                self.known[node["node"]] = {**result, "probed_at": time.time()}
            elif isinstance(result, BaseException):
                log.warning("probing %s failed: %r", node["node"], result)
        self.state_file.write_text(json.dumps(self.known))
        self.tiles = [self._tile(host, ts) for host in self.hosts]

    def _tile(self, host: Host, ts: dict) -> dict:
        active = next((n for n in host.nodes if ts.get(n["node"], {}).get("online")), None)
        # Figures from the active install, else whichever was read most recently
        candidates = [active] if active else sorted(
            host.nodes, key=lambda n: -self.known.get(n["node"], {}).get("probed_at", 0))
        stats = next((self.known[n["node"]] for n in candidates if n["node"] in self.known), None)
        tile = {"name": host.name, "online": active is not None, "os": active["os"] if active else None,
                "multi": len(host.nodes) > 1, "stats": stats, "last_seen": None}
        if stats and active:
            fresh = time.time() - stats["probed_at"] < 600
            tile["uptime"] = stats["uptime"] + (time.time() - stats["probed_at"]) if fresh else None
        if not active:
            seen = [ts[n["node"]]["last_seen"] for n in host.nodes if ts.get(n["node"], {}).get("last_seen")]
            tile["last_seen"] = max(seen) if seen else None
        return tile

