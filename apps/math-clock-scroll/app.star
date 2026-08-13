# Math Clock
#
# Every hour and minute is rendered as an expression that evaluates to
# it. The expression is picked from the clock, so it is stable within
# a minute rather than flickering between renders.



MDAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
MON = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
       "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

# Same table and DST rule as apps/us-sky-clock, so every GDN clock agrees on
# the wall time. [base offset, observes DST]
ZONES = {
    "EASTERN": [-5, True],
    "CENTRAL": [-6, True],
    "MOUNTAIN": [-7, True],
    "ARIZONA": [-7, False],
    "PACIFIC": [-8, True],
    "ALASKA": [-9, True],
    "HAWAII": [-10, False],
}


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


def civil_from_days(z):
    """Days since the Unix epoch -> (year, month, day)."""
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


def nth_sunday(y, month, nth):
    fd = (days_from_civil(y, month, 1) + 4) % 7
    first_sun = 1 + ((7 - fd) % 7)
    return first_sun + (nth - 1) * 7


def is_dst(y, mo, d, h):
    # US rule: second Sunday in March to first Sunday in November.
    start = nth_sunday(y, 3, 2)
    end = nth_sunday(y, 11, 1)
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


def offset_hours(ctx):
    """UTC offset for the configured zone, DST already applied.

    This used to be two cached network hops -- zip -> lat/lon (zippopotam.us),
    then lat/lon -> offset (timeapi.io) -- and every failure path returned 0.0,
    so if either API was down or the zip was unknown the clock quietly showed
    UTC. The zone dropdown resolves the offset locally: no network, no fallback
    to the wrong time."""
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
    uy, umo, ud = civil_from_days((u - usecs) // 86400)
    dst = observes and is_dst(uy, umo, ud, usecs // 3600)
    return float(base + (1 if dst else 0))


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


def lcg(state):
    return (state * 1103515245 + 12345) % 2147483648


def seeded(n):
    return (n * 2654435761) % 2147483647 + 1


def expr(n, state):
    """A small expression equal to n. Falls back to the plain number."""
    forms = []
    for a in range(2, 13):
        if n % a == 0 and n // a > 1 and n // a < 13:
            forms.append(str(a) + "X" + str(n // a))
    for a in range(1, n):
        if n - a > 0 and a < 60 and n - a < 60:
            forms.append(str(a) + "+" + str(n - a))
            break
    if n < 59:
        forms.append(str(n + 1) + "-1")
    if len(forms) == 0:
        return str(n)
    return forms[(state // 512) % len(forms)]


def solve(c, ctx):
    t = local(ctx)
    state = seeded(t["unix"] // 60)
    hh = expr(h12(t["hour"]), state)
    state = lcg(state)
    mm = expr(t["minute"] if t["minute"] > 0 else 60, state)

    c.fill("#07060E")
    if c.width >= 128:
        c.text(hh, c.width // 2 - 8, 8, font = "16x20", color = "#FFD84A",
               align = "right")
        c.text(":", c.width // 2, 12, font = "10x16", color = "#5A5A78",
               align = "center")
        c.text(mm, c.width // 2 + 8, 8, font = "16x20", color = "#7FD4FF")
        c.text("SOLVE THE TIME", c.width // 2, 1, font = "4x5",
               color = "#4A4A66", align = "center")
    else:
        c.text_fit(hh, c.width // 2, 3, ["10x16", "7x12", "6x8"],
                   color = "#FFD84A", align = "center", maxw = c.width - 4)
        c.text_fit(mm, c.width // 2, 18, ["10x16", "7x12", "6x8"],
                   color = "#7FD4FF", align = "center", maxw = c.width - 4)
