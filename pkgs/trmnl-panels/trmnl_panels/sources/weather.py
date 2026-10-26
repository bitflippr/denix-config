"""Current conditions and the next hours from Open-Meteo (no account or key needed)."""

from datetime import datetime

import aiohttp

URL = "https://api.open-meteo.com/v1/forecast"

# WMO weather codes -> (label, kind, day icon, night icon)
_CODES = {
    0: ("Clear", None, "sun", "moon"),
    1: ("Mostly clear", None, "cloud-sun", "cloud-moon"),
    2: ("Partly cloudy", None, "cloud-sun", "cloud-moon"),
    3: ("Cloudy", None, "cloud", "cloud"),
    45: ("Fog", None, "cloud-fog", "cloud-fog"),
    48: ("Fog", None, "cloud-fog", "cloud-fog"),
}
for c in (51, 53, 55, 56, 57):
    _CODES[c] = ("Drizzle", "Rain", "cloud-rain", "cloud-rain")
for c in (61, 63, 65, 66, 67, 80, 81, 82):
    _CODES[c] = ("Rain" if c < 80 else "Showers", "Rain", "cloud-rain", "cloud-rain")
for c in (71, 73, 75, 77, 85, 86):
    _CODES[c] = ("Snow", "Snow", "cloud-snow", "cloud-snow")
for c in (95, 96, 99):
    _CODES[c] = ("Thunderstorms", "Storms", "cloud-lightning", "cloud-lightning")


def describe(code: int, is_day: bool) -> tuple[str, str | None, str]:
    label, kind, day, night = _CODES.get(code, ("Unknown", None, "cloud", "cloud"))
    return label, kind, day if is_day else night


async def fetch(session: aiohttp.ClientSession, lat: float, lon: float, tz: str) -> dict:
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": "temperature_2m,weather_code,is_day",
        "hourly": "temperature_2m,precipitation_probability,weather_code,is_day",
        "daily": "temperature_2m_max,temperature_2m_min,sunrise,sunset",
        "temperature_unit": "fahrenheit",
        "timezone": tz,
        "forecast_days": 2,
    }
    async with session.get(URL, params=params, timeout=aiohttp.ClientTimeout(total=20)) as r:
        r.raise_for_status()
        return await r.json()


def _hour_label(t: datetime) -> str:
    return t.strftime("%-I %p").replace(":00", "")


def summarize(raw: dict, now: datetime) -> dict:
    """Shape Open-Meteo's response for the panels. `now` is local time."""
    cur = raw["current"]
    label, kind, icon = describe(cur["weather_code"], bool(cur["is_day"]))

    hours = []
    for i, ts in enumerate(raw["hourly"]["time"]):
        t = datetime.fromisoformat(ts)
        if t < now.replace(minute=0, second=0, microsecond=0, tzinfo=None):
            continue
        h_label, h_kind, h_icon = describe(raw["hourly"]["weather_code"][i], bool(raw["hourly"]["is_day"][i]))
        hours.append({
            "time": t,
            "temp": round(raw["hourly"]["temperature_2m"][i]),
            "precip": raw["hourly"]["precipitation_probability"][i] or 0,
            "kind": h_kind,
            "icon": h_icon,
        })
        if len(hours) == 13:
            break

    # One line about what's coming: when precipitation starts or stops, else sunset/sunrise
    upcoming = hours[1:]
    if kind:
        stop = next((h for h in upcoming if not h["kind"] and h["precip"] < 40), None)
        note = f"{kind} until {_hour_label(stop['time'])}" if stop else f"{kind} all day"
    else:
        start = next((h for h in upcoming if h["kind"] or h["precip"] >= 50), None)
        if start:
            note = f"{start['kind'] or 'Rain'} from {_hour_label(start['time'])}"
        else:
            sunset = datetime.fromisoformat(raw["daily"]["sunset"][0])
            sunrise = datetime.fromisoformat(raw["daily"]["sunrise"][1])
            naive_now = now.replace(tzinfo=None)
            note = (f"Sunset {sunset.strftime('%-I:%M %p')}" if naive_now < sunset
                    else f"Sunrise {sunrise.strftime('%-I:%M %p')}")

    return {
        "temp": round(cur["temperature_2m"]),
        "label": label,
        "icon": icon,
        "high": round(raw["daily"]["temperature_2m_max"][0]),
        "low": round(raw["daily"]["temperature_2m_min"][0]),
        "note": note,
        "hours": hours[1:13:2],  # every other hour for the next 12
    }
