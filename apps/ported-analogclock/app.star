# Ported from the tidbyt/community "Analog Clock" app (apps/analogclock/analog_clock.star).
#
# ORIGINAL Pixlet: renders an analog clock by compositing PRE-RENDERED base64 PNG
# hand images (a separate image per minute/hour-hand position) in a render.Stack,
# with the month and day drawn beside it.
#
# `gdn translate` flagged base64/json/time/load() and the Stack/Image/Text
# widgets. Hand-finished for GDN (static 64x32): rather than ship dozens of hand
# PNGs, the render approach was REWRITTEN - the hands are computed with trig and
# drawn with c.line from ctx.now (+ a time-zone input), the face is drawn with
# hour ticks, and the month/day sit to the right.
#
PI2 = 6.283185307179586
MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

# ---------- time zone ----------
# ctx.now is UTC. Each US zone is "UTC minus N hours", plus an hour while
# daylight saving is in effect. Same table and DST rule as apps/us-sky-clock,
# so the two apps always agree on the wall clock.
# [base offset, observes DST]
ZONES = {
    "EASTERN": [-5, True],
    "CENTRAL": [-6, True],
    "MOUNTAIN": [-7, True],
    "ARIZONA": [-7, False],
    "PACIFIC": [-8, True],
    "ALASKA": [-9, True],
    "HAWAII": [-10, False],
}

def _days_from_civil(y, m, d):
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    mm = m + (-3 if m > 2 else 9)
    doy = (153 * mm + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468

def _nth_sunday(y, month, nth):
    fd = (_days_from_civil(y, month, 1) + 4) % 7
    first_sun = 1 + ((7 - fd) % 7)
    return first_sun + (nth - 1) * 7

def _is_dst(y, mo, d, h):
    # US rule: second Sunday in March to first Sunday in November.
    start = _nth_sunday(y, 3, 2)
    end = _nth_sunday(y, 11, 1)
    if mo < 3 or mo > 11:
        return False
    if mo > 3 and mo < 11:
        return True
    if mo == 3:
        if d > start:
            return True
        if d < start:
            return False
        return h >= 2
    if d < end:
        return True
    if d > end:
        return False
    return h < 2

def _zone_offset(ctx):
    """Resolve the zone dropdown to a UTC offset in hours, DST included."""
    zone = ctx.inputs.get("zone", "EASTERN")
    if zone == None:
        zone = "EASTERN"
    zone = zone.upper()
    if zone not in ZONES:
        zone = "EASTERN"
    base = ZONES[zone][0]
    observes = ZONES[zone][1]
    u = ctx.now.unix
    usecs = u % 86400
    uy, umo, ud = _civil_from_days((u - usecs) // 86400)
    dst = observes and _is_dst(uy, umo, ud, usecs // 3600)
    return base + (1 if dst else 0)

def _civil_from_days(z):
    # Days since 1970-01-01 -> (year, month, day). Needed because the date has
    # to come from the OFFSET time, not from UTC -- otherwise the day flips
    # hours early or late depending on which side of UTC you are on.
    z = z + 719468
    era = (z if z >= 0 else z - 146096) // 146097
    doe = z - era * 146097
    yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    y = yoe + era * 400
    doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    mp = (5 * doy + 2) // 153
    d = doy - (153 * mp + 2) // 5 + 1
    m = mp + 3 if mp < 10 else mp - 9
    if m <= 2:
        y = y + 1
    return y, m, d

def main(c, ctx):
    off = _zone_offset(ctx)

    local = ctx.now.unix + off * 3600
    secs = local % 86400
    hh = secs // 3600
    mm = (secs % 3600) // 60

    # The date comes from the same shifted timestamp as the hands, so the two
    # never disagree near midnight.
    days = (local - secs) // 86400
    year, month, day = _civil_from_days(days)

    cx = 15
    cy = 15
    r = 14

    c.fill("black")

    # face: 12 hour ticks (brighter at 12/3/6/9)
    for i in range(12):
        a = PI2 * i / 12.0
        tx = cx + int(r * math.sin(a) + 0.5)
        ty = cy - int(r * math.cos(a) + 0.5)
        col = "white" if i % 3 == 0 else "midgray"
        c.pixel(tx, ty, col)

    # hands
    min_a = PI2 * mm / 60.0
    hour_a = PI2 * ((hh % 12) + mm / 60.0) / 12.0
    mlen = r - 2
    hlen = r - 6
    c.line(cx, cy, cx + int(mlen * math.sin(min_a) + 0.5), cy - int(mlen * math.cos(min_a) + 0.5), "white")
    c.line(cx, cy, cx + int(hlen * math.sin(hour_a) + 0.5), cy - int(hlen * math.cos(hour_a) + 0.5), "yellow")
    c.rect(cx - 1, cy - 1, cx + 1, cy + 1, fill = "red")

    # month + day to the right
    c.text(MONTHS[month - 1], 48, 4, font = "5x7", color = "cyan", align = "center")
    c.text(str(day), 48, 13, font = "10x16", color = "white", align = "center")