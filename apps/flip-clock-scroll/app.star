# Flip Clock
#
# The old airport split-flap board. Each card is a rounded panel with
# the seam across its middle, which is what makes the glyph read as a
# flap rather than plain text on a box.



MDAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
MON = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
       "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


def is_leap(y):
    return (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0)


def days_from_civil(y, m, d):
    """Days since the Unix epoch (Howard Hinnant's algorithm)."""
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    mp = m - 3 if m > 2 else m + 9
    doy = (153 * mp + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468


def offset_hours(ctx):
    """Real UTC offset for the configured zip, DST already applied.

    Two cached hops: zip -> lat/lon, then lat/lon -> offset. Any failure falls
    back to UTC, so a dead API costs you the timezone, not the panel."""
    zip = str(ctx.inputs.get("zip", "")).strip()
    if zip == "":
        return 0.0
    g = http.get("https://api.zippopotam.us/us/" + zip, ttl_seconds = 86400)
    if g["status_code"] != 200 or not g["json"]:
        return 0.0
    places = g["json"].get("places", [])
    if not places:
        return 0.0
    t = http.get(
        "https://timeapi.io/api/TimeZone/coordinate",
        params = {"latitude": places[0]["latitude"],
                  "longitude": places[0]["longitude"]},
        ttl_seconds = 3600,
    )
    if t["status_code"] != 200 or not t["json"]:
        return 0.0
    secs = t["json"].get("currentUtcOffset", {}).get("seconds", None)
    if secs == None:
        return 0.0
    return float(secs) / 3600.0


def local(ctx):
    """ctx.now shifted onto the viewer's wall clock."""
    shifted = ctx.now.unix + int(offset_hours(ctx) * 3600)
    days = shifted // 86400
    secs = shifted % 86400
    weekday = (days + 3) % 7           # 1970-01-01 was a Thursday
    y = 1970
    for i in range(400):
        span = 366 if is_leap(y) else 365
        if days < span:
            break
        days -= span
        y += 1
    m = 0
    yd = days
    for i in range(12):
        span = MDAYS[m] + (1 if (m == 1 and is_leap(y)) else 0)
        if days < span:
            break
        days -= span
        m += 1
    return {"year": y, "month": m + 1, "day": days + 1, "weekday": weekday,
            "yday": yd + 1, "hour": secs // 3600, "minute": (secs % 3600) // 60,
            "second": secs % 60, "secs": secs, "unix": shifted}


def h12(h):
    v = h % 12
    return 12 if v == 0 else v


def card(c, x, y, w, h, text, font, accent):
    c.round_rect(x, y, x + w - 1, y + h - 1, 2, fill = "#15161F")
    c.round_rect(x, y, x + w - 1, y + h - 1, 2, outline = "#2C2E3E")
    c.text(text, x + w // 2, y + (h - _fh(font)) // 2, font = font,
           color = accent, align = "center")
    # the seam the flap folds on
    c.hline(x + 1, y + h // 2, w - 2, "#05060A")


def _fh(font):
    return {"16x20": 20, "10x16": 16, "7x12": 12, "6x8": 8, "5x7": 7, "4x5": 5}[font]


def board(c, cells, font, accent, gap):
    """Lay a row of cards out centred on the panel.

    Each card is sized to its own contents. Sizing every card for two digits
    made the date board's words spill straight out of their flaps."""
    ch = _fh(font) + 6
    widths = []
    total = 0
    for s in cells:
        w = c.text_width(s, font) + 6
        widths.append(w)
        total += w
    total += (len(cells) - 1) * gap
    x = (c.width - total) // 2
    y = (c.height - ch) // 2
    for i in range(len(cells)):
        card(c, x, y, widths[i], ch, cells[i], font, accent)
        x += widths[i] + gap


def clock(c, ctx):
    t = local(ctx)
    accent = ctx.inputs.get("accent", "#F5E14B")
    c.fill("#05060A")
    font = "16x20" if c.width >= 128 else "10x16"
    board(c, [fmt.pad(h12(t["hour"])), fmt.pad(t["minute"])], font, accent, 4)
    if c.width >= 128:
        c.text("AM" if t["hour"] < 12 else "PM", c.width - 8, 12, font = "6x8",
               color = "#6A6C86", align = "right")


def date(c, ctx):
    t = local(ctx)
    accent = ctx.inputs.get("accent", "#F5E14B")
    c.fill("#05060A")
    if c.width >= 128:
        board(c, [DOW[t["weekday"]], MON[t["month"] - 1], str(t["day"])],
              "10x16", accent, 4)
    else:
        # Three word-cards are wider than 64px however they are packed, so the
        # small panel drops the weekday and keeps the part you came for.
        board(c, [MON[t["month"] - 1], str(t["day"])], "6x8", accent, 3)
        c.text(DOW[t["weekday"]], c.width // 2, 1, font = "4x5",
               color = "#6A6C86", align = "center")
