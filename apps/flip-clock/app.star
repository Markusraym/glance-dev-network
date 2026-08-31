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


def card(c, x, y, w, h, text, font, accent, seam = True):
    c.round_rect(x, y, x + w - 1, y + h - 1, 2, fill = "#15161F")
    c.round_rect(x, y, x + w - 1, y + h - 1, 2, outline = "#2C2E3E")
    c.text(text, x + w // 2, y + (h - _fh(font)) // 2, font = font,
           color = accent, align = "center")
    # The seam the flap folds on. It is drawn only where it reads as a fold:
    # across a 20-row digit it costs one row in twenty, but across an 8-row
    # word it takes the row that joins P's bowl to its stem and M's peaks to
    # its legs, and the word stops being a word.
    if seam:
        c.hline(x + 1, y + h // 2, w - 2, "#05060A")


def _fh(font):
    return {"16x20": 20, "10x16": 16, "7x12": 12, "6x8": 8, "5x7": 7, "4x5": 5}[font]


def board(c, cells, accent, gap):
    """Lay a row of cards out centred on the panel.

    A cell is [text, font]: each card is sized to its own contents AND its own
    face, and every card is centred on the panel's middle row. Carrying the
    face per cell is what lets a small flap sit in the same rank as the big
    ones -- the meridiem used to be loose text pinned to the right edge, which
    read as a label ABOUT the clock rather than a flap of it. Sizing every card
    for two digits, meanwhile, made the date board's words spill out of their
    flaps."""
    widths, heights = [], []
    total = 0
    for cell in cells:
        w = c.text_width(cell[0], cell[1]) + 6
        widths.append(w)
        heights.append(_fh(cell[1]) + 6)
        total += w
    total += (len(cells) - 1) * gap
    x = (c.width - total) // 2
    for i in range(len(cells)):
        card(c, x, (c.height - heights[i]) // 2, widths[i], heights[i],
             cells[i][0], cells[i][1], accent, _fh(cells[i][1]) >= 12)
        x += widths[i] + gap


def clock(c, ctx):
    t = local(ctx)
    accent = ctx.inputs.get("accent", "#F5E14B")
    c.fill("#05060A")
    hh, mm = fmt.pad(h12(t["hour"])), fmt.pad(t["minute"])
    if c.width >= 128:
        # The meridiem gets a flap of its own, in the same centred row as the
        # hour and the minute. A 64 panel has no room for a third flap beside
        # a 10x16 time -- two flaps and a gap already take 58 of its 64
        # columns -- so it keeps the two it can read at a glance.
        board(c, [[hh, "16x20"], [mm, "16x20"],
                  ["AM" if t["hour"] < 12 else "PM", "6x8"]], accent, 4)
    else:
        board(c, [[hh, "10x16"], [mm, "10x16"]], accent, 4)


def date(c, ctx):
    t = local(ctx)
    accent = ctx.inputs.get("accent", "#F5E14B")
    c.fill("#05060A")
    if c.width >= 128:
        board(c, [[DOW[t["weekday"]], "10x16"], [MON[t["month"] - 1], "10x16"],
                  [str(t["day"]), "10x16"]], accent, 4)
    else:
        # The day of the month is what anyone actually reads off a date, so it
        # takes the clock's own 10x16 face and the month stays a small flap
        # beside it: 56 of the 64 columns. Three word-flaps do not fit at any
        # size, and the weekday was the one part still floating loose rather
        # than riding a flap, so it goes rather than break the object.
        board(c, [[MON[t["month"] - 1], "6x8"], [str(t["day"]), "10x16"]],
              accent, 3)
