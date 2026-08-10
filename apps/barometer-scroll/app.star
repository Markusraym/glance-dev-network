# Barometer
#
# Pressure alone tells you little; the trend over three hours tells
# you a lot, which is why ships' barometers were read that way for
# two centuries. A fall of more than about 2 hPa in three hours is
# a genuine sign of weather on the way.



def geo(ctx):
    """[lat, lon, place] for the configured zip, or None when unavailable."""
    zip = str(ctx.inputs.get("zip", "")).strip()
    if zip == "":
        return None
    g = http.get("https://api.zippopotam.us/us/" + zip, ttl_seconds = 86400)
    if g["status_code"] != 200 or not g["json"]:
        return None
    places = g["json"].get("places", [])
    if not places:
        return None
    p = places[0]
    return [float(p["latitude"]), float(p["longitude"]),
            str(p.get("place name", "")).upper()]


NODATA_FONTS = ["10x16", "6x8", "5x7", "4x5"]


def _fit_clip(c, text, fonts, maxw):
    """[font, text] for the largest font that fits, clipping if none do.

    text_fit alone was not enough here: when even its smallest option
    overflows it still draws, which ran these messages off a 64 panel."""
    pick = fonts[len(fonts) - 1]
    for f in fonts:
        if c.text_width(text, f) <= maxw:
            pick = f
            break
    t = text
    if c.text_width(t, pick) > maxw:
        for k in range(len(t), 0, -1):
            if c.text_width(t[:k], pick) <= maxw:
                t = t[:k]
                break
    return [pick, t]


def nodata(c, title, sub):
    """Shown whenever a feed is unreachable or a key is missing.

    Every network app needs one: the publish-time validator renders each page
    with the network disabled, and a panel on a wall must say something
    sensible rather than going blank.

    The two lines get explicit, non-overlapping bands — a 16px title centred
    on the panel ran straight through the line beneath it.
    Wide:   4-19 title | 22-28 detail
    Narrow: 5-12 title | 18-22 detail
    """
    c.fill("#0B0C12")
    maxw = c.width - 6
    if c.width >= 128:
        t = _fit_clip(c, title, NODATA_FONTS, maxw)
        c.text(t[1], c.width // 2, 4, font = t[0], color = "#E8B04A",
               align = "center")
        d = _fit_clip(c, sub, ["5x7", "4x5"], maxw)
        c.text(d[1], c.width // 2, 22, font = d[0], color = "#6A7090",
               align = "center")
    else:
        t = _fit_clip(c, title, ["6x8", "5x7", "4x5"], maxw)
        c.text(t[1], c.width // 2, 5, font = t[0], color = "#E8B04A",
               align = "center")
        d = _fit_clip(c, sub, ["4x5"], maxw)
        c.text(d[1], c.width // 2, 18, font = d[0], color = "#6A7090",
               align = "center")


def pressure(c, ctx):
    g = geo(ctx)
    if g == None:
        nodata(c, "NO LOCATION", "SET A ZIP")
        return
    r = http.get("https://api.open-meteo.com/v1/forecast",
                 params = {"latitude": str(g[0]), "longitude": str(g[1]),
                           "hourly": "pressure_msl", "past_hours": "6",
                           "forecast_hours": "1", "timezone": "auto"},
                 ttl_seconds = 1800)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO PRESSURE", "NO CONNECTION")
        return
    vals = r["json"].get("hourly", {}).get("pressure_msl", [])
    clean = []
    for v in vals:
        if v != None:
            clean.append(float(v))
    if len(clean) < 2:
        nodata(c, "NO PRESSURE", "EMPTY FEED")
        return

    now = clean[len(clean) - 1]
    back = clean[0] if len(clean) < 4 else clean[len(clean) - 4]
    delta = now - back

    if delta <= -2.0:
        trend = "FALLING FAST"
        col = "#FF5B5B"
        note = "WEATHER COMING"
    elif delta <= -0.7:
        trend = "FALLING"
        col = "#FF9A4A"
        note = "TURNING UNSETTLED"
    elif delta < 0.7:
        trend = "STEADY"
        col = "#6FD4FF"
        note = "NO BIG CHANGE"
    elif delta < 2.0:
        trend = "RISING"
        col = "#8FE38A"
        note = "SETTLING DOWN"
    else:
        trend = "RISING FAST"
        col = "#4EE38A"
        note = "CLEARING"

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#0A0C12", "#1E2434",
                    horizontal = False)
    sz = 24 if c.width >= 128 else 16
    c.image("GAUGE.png", 1, (c.height - sz) // 2, w = sz, h = sz)

    if c.width >= 128:
        # Trend column first, then the reading fitted to what is left, then
        # the detail line on its own row.
        c.text_fit(trend, c.width - 6, 3, ["10x16", "6x8"], color = col,
                   align = "right", maxw = c.width - 130)
        c.text_fit(str(int(now)) + " HPA", 30, 4, ["16x20", "10x16", "6x8"],
                   color = "#DCE4F4", maxw = c.width - 130)
        sign = "+" if delta >= 0 else ""
        c.text(sign + str(int(delta * 10) / 10.0) + " IN 3H   " + note,
               c.width - 6, 24, font = "5x7", color = "#96A0B8",
               align = "right")
    else:
        c.text_fit(str(int(now)), c.width - 2, 3, ["16x20", "10x16"],
                   color = "#DCE4F4", align = "right", maxw = c.width - 20)
        c.text_fit(trend, c.width - 2, 25, ["4x5", "3x4"], color = col,
                   align = "right", maxw = c.width - 4)
