# Binary Clock
#
# Two ways to read the time in binary. BCD gives a column per decimal
# digit, the way a classic binary desk clock does; BITS gives one row
# per unit, which is easier to decode once you are used to it.



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


BITS = [8, 4, 2, 1]


def dot(c, x, y, r, on, accent):
    if on:
        c.fill_circle(x, y, r, accent)
    else:
        c.circle(x, y, r, "#1E2233")


def bcd(c, ctx):
    """One column per decimal digit, lit dots reading downward as 8-4-2-1."""
    t = local(ctx)
    accent = ctx.inputs.get("accent", "#3FC8FF")
    digits = [t["hour"] // 10, t["hour"] % 10, t["minute"] // 10,
              t["minute"] % 10, t["second"] // 10, t["second"] % 10]

    c.fill("#05070E")
    r = 2 if c.width >= 128 else 1
    step = 2 * r + 3
    block = 6 * step + 2 * (2 * r + 2)
    # On the Scroll the dots take the left half and leave the right to the
    # faint plain reading; centring the block ran the two together.
    x0 = (8 + r) if c.width >= 128 else ((c.width - block) // 2 + r)
    y0 = (c.height - 4 * step) // 2 + r + 3

    for i in range(6):
        x = x0 + i * step + (i // 2) * (2 * r + 2)
        for b in range(4):
            dot(c, x, y0 + b * step, r, digits[i] // BITS[b] % 2 == 1, accent)
    c.text("H   M   S", x0 + 3 * step + r, 1, font = "4x5",
           color = "#4A5068", align = "center")
    if c.width >= 128:
        # The dot cluster alone leaves most of a 192 panel empty, so the Scroll
        # also carries the plain reading to check yourself against.
        c.text(fmt.pad(t["hour"]) + ":" + fmt.pad(t["minute"]),
               c.width - 10, 7, font = "16x20", color = "#22304A",
               align = "right")


def bits(c, ctx):
    """One row per unit: hours, minutes, seconds as plain binary."""
    t = local(ctx)
    accent = ctx.inputs.get("accent", "#3FC8FF")
    rows = [["H", t["hour"], 5], ["M", t["minute"], 6], ["S", t["second"], 6]]

    c.fill("#05070E")
    r = 2 if c.width >= 128 else 1
    step = 2 * r + 3
    y0 = (c.height - 3 * step) // 2 + r

    for i in range(3):
        label = rows[i][0]
        val = rows[i][1]
        nbits = rows[i][2]
        y = y0 + i * step
        c.text(label, 3, y - 2, font = "4x5", color = "#4A5068")
        x0 = 11 + r
        for b in range(nbits):
            place = nbits - 1 - b
            p = 1
            for k in range(place):
                p = p * 2
            dot(c, x0 + b * step, y, r, val // p % 2 == 1, accent)
        if c.width >= 128:
            # 4x5, not 6x8: the row pitch here is 7px and an 8px glyph runs
            # straight into the row below it.
            c.text(fmt.pad(val), c.width - 6, y - 2, font = "4x5",
                   color = "#C8D0E8", align = "right")
