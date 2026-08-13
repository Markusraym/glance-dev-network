# Beach Day
#
# Four things decide a beach day and no single one of them settles
# it, so they are scored together: warmth, low rain chance, gentle
# wind, and enough UV to be worth the sunscreen but not so much it
# is punishing.



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


def score(c, ctx):
    g = geo(ctx)
    if g == None:
        nodata(c, "NO LOCATION", "SET A ZIP")
        return
    metric = str(ctx.inputs.get("units", "IMPERIAL")).upper() == "METRIC"
    r = http.get("https://api.open-meteo.com/v1/forecast",
                 params = {"latitude": str(g[0]), "longitude": str(g[1]),
                           "daily": "temperature_2m_max,precipitation_probability_max,wind_speed_10m_max,uv_index_max",
                           "temperature_unit": "celsius" if metric else "fahrenheit",
                           "wind_speed_unit": "kmh" if metric else "mph",
                           "timezone": "auto", "forecast_days": "1"},
                 ttl_seconds = 3600)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO FORECAST", "NO CONNECTION")
        return
    d = r["json"].get("daily", {})

    def first(key):
        v = d.get(key, [])
        return float(v[0] or 0) if len(v) > 0 and v[0] != None else 0.0

    temp = first("temperature_2m_max")
    rain = first("precipitation_probability_max")
    wind = first("wind_speed_10m_max")
    uv = first("uv_index_max")

    tempf = temp if not metric else temp * 9 / 5 + 32
    windm = wind if not metric else wind * 0.621371

    # Warmth carries the most weight; rain is the strongest veto.
    warm = 100.0 - abs(tempf - 82.0) * 4.0
    if warm < 0:
        warm = 0.0
    dry = 100.0 - rain
    calm = 100.0 - windm * 4.0
    if calm < 0:
        calm = 0.0
    sun = 100.0 - abs(uv - 6.0) * 12.0
    if sun < 0:
        sun = 0.0
    total = int(warm * 0.40 + dry * 0.30 + calm * 0.20 + sun * 0.10)

    if total >= 75:
        verdict = "PERFECT"
        col = "#4EE38A"
    elif total >= 55:
        verdict = "GOOD"
        col = "#F5D64E"
    elif total >= 35:
        verdict = "SO-SO"
        col = "#FF9A4A"
    else:
        verdict = "STAY HOME"
        col = "#FF5B5B"

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#0B1C2E", "#2C4A66",
                    horizontal = False)
    n = 24 if c.width >= 128 else 16
    c.image("UMBRELLA.png", 2, c.height - n + 4, w = n, h = n)

    if c.width >= 128:
        c.text(str(total), 30, 6, font = "16x20", color = col)
        c.text_fit(verdict, c.width - 6, 3, ["10x16", "6x8"], color = col,
                   align = "right", maxw = c.width - 100)
        c.text(str(int(temp)) + "\u00B0  " + str(int(rain)) + "% RAIN  "
               + str(int(wind)) + (" KMH" if metric else " MPH"),
               c.width - 6, 23, font = "5x7", color = "#B4CCE0",
               align = "right")
    else:
        c.text_fit(str(total), c.width - 2, 3, ["16x20", "10x16"], color = col,
                   align = "right", maxw = c.width - 20)
        c.text_fit(verdict, c.width - 2, 25, ["4x5", "3x4"], color = col,
                   align = "right", maxw = c.width - 4)
