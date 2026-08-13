# Ported from the tidbyt/community "Binary Clock" app (apps/binaryclock/binary_clock.star).
#
# ORIGINAL Pixlet: six columns (Year, Month, Day, Hour, Minute, Second), each a
# render.Column of render.Box "dots" showing that value in binary (up to 11 bits
# via log2(MAX_VALUE=2048)), with a letter label beneath. It builds 30 frames one
# second apart and plays them as a render.Animation.
#
# `gdn translate` flagged the Location schema + time.*/math.*/json/load() and the
# Row/Column/Box/Animation/Text widgets. Hand-finished for GDN (static 64x32):
# GDN v1 is a single frame, so this is the snapshot at the frozen ctx.now; the
# render.Box dot grid became c.rect calls. Year is shown as 2 digits so all the
# columns fit 32px tall.
#
# The Location schema became a time-zone input -- the original read local time
# and this was rendering raw UTC. Bit color is configurable, as it was upstream.

NBITS = 7
POW = [64, 32, 16, 8, 4, 2, 1]

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
    # Days since 1970-01-01 -> (year, month, day), so the date matches the
    # OFFSET time rather than UTC.
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

def _dim(col, amt):
    # Scale a #RRGGBB toward black, for the unlit bits.
    d = "0123456789ABCDEF"
    s = col.upper()
    out = "#"
    for i in range(3):
        hi = d.index(s[1 + i * 2])
        lo = d.index(s[2 + i * 2])
        v = int((hi * 16 + lo) * amt)
        if v > 255:
            v = 255
        out = out + d[v // 16] + d[v % 16]
    return out

def main(c, ctx):
    off = _zone_offset(ctx)
    on_col = ctx.inputs.get("oncolor", "#FF0000")
    show_secs = ctx.inputs.get("showseconds", "no") == "yes"

    # Shift UTC to local, then read every field off that one timestamp so the
    # date and the clock can never disagree near midnight.
    local = ctx.now.unix + off * 3600
    secs = local % 86400
    hour = secs // 3600
    minute = (secs % 3600) // 60
    second = secs % 60

    days = (local - secs) // 86400
    year, month, day = _civil_from_days(days)

    cols = [
        [year % 100, "Y"],
        [month, "M"],
        [day, "D"],
        [hour, "H"],
        [minute, "M"],
    ]
    if show_secs:
        cols.append([second, "S"])

    off_col = _dim(on_col, 0.16)

    c.fill("black")

    ncols = len(cols)
    colw = c.width // ncols
    sqw = colw - 4
    if sqw > 8:
        sqw = 8
    sqh = 2
    gap = 1
    top = 3

    for i in range(ncols):
        val = cols[i][0]
        label = cols[i][1]
        cx = i * colw + (colw - sqw) // 2

        for r in range(NBITS):
            bit = (val // POW[r]) % 2
            y = top + r * (sqh + gap)
            fill = on_col if bit == 1 else off_col
            c.rect(cx, y, cx + sqw - 1, y + sqh - 1, fill = fill)

        ly = top + NBITS * (sqh + gap) + 1
        c.text(label, i * colw + colw // 2, ly, font = "4x5", color = "white", align = "center")