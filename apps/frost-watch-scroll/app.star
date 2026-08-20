# Frost Watch
#
# One question, answered plainly: does anything need covering
# tonight? The thresholds are the ones gardeners actually use —
# frost forms around 36F because the air at thermometer height is
# warmer than the ground, and a hard freeze starts at 28F.



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


def degree_mark(c, x, y, color):
    """Draw the degree ring. None of the bitmap fonts carry a U+00B0 glyph, so
    a literal "°" in a string measures 0px wide and draws nothing at all --
    the temperature silently rendered as a bare number. Radius 1 gives the 3x3
    ring that reads as a degree at LED scale."""
    c.circle(x + 1, y + 1, 1, color)


def temp_group_width(c, s, font, unit):
    w = c.text_width(s, font) + 4
    if unit != "":
        w = w + 2 + c.text_width(unit, "5x7")
    return w


def draw_temp(c, x, y, s, font, color, unit):
    """Temperature + degree ring, drawn left-to-right from x. `unit` adds the
    F/C letter after the ring; pass "" on narrow panels, where the ring alone
    keeps the number in the big font. Returns the width drawn."""
    w = c.text_width(s, font)
    c.text(s, x, y, font = font, color = color)
    degree_mark(c, x + w + 1, y + 1, color)
    if unit != "":
        c.text(unit, x + w + 6, y + 1, font = "5x7", color = color)
    return temp_group_width(c, s, font, unit)


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


def band(f):
    """Thresholds in Fahrenheit, the units the advice is written in."""
    if f <= 28:
        return ["HARD FREEZE", "#8FD4FF", "COVER EVERYTHING"]
    if f <= 32:
        return ["FREEZE", "#BFE6FF", "COVER TENDER PLANTS"]
    if f <= 36:
        return ["FROST RISK", "#DCF0FF", "COVER IF IN DOUBT"]
    if f <= 45:
        return ["CHILLY", "#8FE3B0", "NOTHING TO DO"]
    return ["MILD", "#6FE38A", "NOTHING TO DO"]


def tonight(c, ctx):
    g = geo(ctx)
    if g == None:
        nodata(c, "NO LOCATION", "SET A ZIP")
        return
    r = http.get("https://api.open-meteo.com/v1/forecast",
                 params = {"latitude": str(g[0]), "longitude": str(g[1]),
                           "daily": "temperature_2m_min",
                           "temperature_unit": "fahrenheit",
                           "timezone": "auto", "forecast_days": "2"},
                 ttl_seconds = 3600)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO FORECAST", "NO CONNECTION")
        return
    lows = r["json"].get("daily", {}).get("temperature_2m_min", [])
    if len(lows) == 0 or lows[0] == None:
        nodata(c, "NO FORECAST", "EMPTY FEED")
        return

    f = float(lows[0])
    b = band(f)
    metric = str(ctx.inputs.get("units", "IMPERIAL")).upper() == "METRIC"
    shown = str(int((f - 32) * 5 / 9)) if metric else str(int(f))

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#050A16", "#12203A",
                    horizontal = False)
    n = 24 if c.width >= 128 else 16
    c.image("FROST.png", 2, (c.height - n) // 2, w = n, h = n)

    unit = "C" if metric else "F"
    city = g[2]

    if c.width >= 128:
        # Header row has to be 4x5: the 3x4 font has no space glyph at all, so
        # "TONIGHT LOW IN SAN FRANCISCO" renders as one run-on word in it.
        # 4x5 needs rows 0-5, which the band word at 10x16 was eating into --
        # "HARD FREEZE" is 117px and reached back to x=69. At 8x12 it stops at
        # x=98 and still reads as the headline, which buys the header its row.
        c.text(b[0], c.width - 6, 4, font = "8x12", color = b[1],
               align = "right")
        room = c.width - 6 - c.text_width(b[0], "8x12") - 34
        head = city if city != "" else "TONIGHT LOW"
        hf = _fit_clip(c, head, ["4x5"], room)
        c.text(hf[1], 30, 0, font = hf[0], color = "#5E7290")
        draw_temp(c, 30, 8, shown, "16x20", b[1], unit)
        c.text(b[2], c.width - 6, 23, font = "5x7", color = "#7C90AC",
               align = "right")
    else:
        # city 0-4, temperature 6-25, band word 27-31: no row is shared.
        if city != "":
            cf = _fit_clip(c, city, ["4x5", "3x4"], c.width - 2)
            c.text(cf[1], c.width // 2, 0, font = cf[0], color = "#5E7290",
                   align = "center")
        tfont = "16x20"
        if temp_group_width(c, shown, tfont, "") > c.width - 22:
            tfont = "10x16"
        tw = temp_group_width(c, shown, tfont, "")
        draw_temp(c, c.width - 2 - tw, 6, shown, tfont, b[1], "")
        # 4x5 only, and against the full width. 3x4 has no space glyph, so
        # "HARD FREEZE" came out as "HARDFREEZE" -- and it was reaching that
        # fallback needlessly: maxw was width-20, leaving 44px, but the 20px
        # reserve is for the icon and the icon ends at row 23. Nothing else is
        # on rows 27-31, so the band word can have the panel. At width-4 it
        # gets 60px, and the longest word is 52px at 4x5.
        c.text_fit(b[0], c.width - 2, 27, ["4x5"], color = b[1],
                   align = "right", maxw = c.width - 4)
