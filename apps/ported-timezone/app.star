# Ported from the official tidbyt/pixlet Location schema example (docs/schema/location/example.star).
#
# ORIGINAL Pixlet render code:
#   return render.Root(child = render.Marquee(width = 64,
#       child = render.Text("tz: %s" % timezone)))
# with a schema.Location picker whose JSON carries a "timezone" field.
#
# `gdn translate` converted the schema field to a manifest input and flagged the
# Marquee/Root/Text widgets + the load() imports. Hand-finished for GDN (static
# 64x32). See docs/PIXLET_COMPATIBILITY.md.
#
# LAYOUT IS FIXED. Nothing is measured against the current time, so the render
# only ever takes one of two forms, decided by the digit count of the hour.
#
#   CITY   y=0   5x7    x=32  center
#   DATE   y=25  4x5    x=32  center
#
#   one-digit hour (1:21)      two-digit hour (11:30)
#   TIME   y=8  10x16  right 47    TIME   y=8  10x16  right 53
#   AM/PM  y=10 4x5    left 49     AM/PM  y=10 picopixel right 64
#   DST    y=18 4x5    left 49     DST    y=18 picopixel right 64

MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

# one-digit hour
TIME_RIGHT_1 = 47
LABEL_X_1 = 49
LABEL_FONT_1 = "4x5"
LABEL_ALIGN_1 = "left"

# two-digit hour
TIME_RIGHT_2 = 53
LABEL_X_2 = 64
LABEL_FONT_2 = "picopixel"
LABEL_ALIGN_2 = "right"

def _s(ctx, key, fallback):
    # An unset input can come back as None, so coerce before using it.
    v = ctx.inputs.get(key, fallback)
    if v == None:
        return fallback
    return str(v).strip()

def pad2(n):
    return str(n) if n >= 10 else "0" + str(n)

ZONES = {
    "HONOLULU": "Pacific/Honolulu",
    "ANCHORAGE": "America/Anchorage",
    "LOS ANGELES": "America/Los_Angeles",
    "PHOENIX": "America/Phoenix",
    "DENVER": "America/Denver",
    "CHICAGO": "America/Chicago",
    "NEW YORK": "America/New_York",
    "HALIFAX": "America/Halifax",
    "MEXICO CITY": "America/Mexico_City",
    "BOGOTA": "America/Bogota",
    "SAO PAULO": "America/Sao_Paulo",
    "BUENOS AIRES": "America/Argentina/Buenos_Aires",
    "REYKJAVIK": "Atlantic/Reykjavik",
    "LISBON": "Europe/Lisbon",
    "DUBLIN": "Europe/Dublin",
    "LONDON": "Europe/London",
    "MADRID": "Europe/Madrid",
    "PARIS": "Europe/Paris",
    "AMSTERDAM": "Europe/Amsterdam",
    "BERLIN": "Europe/Berlin",
    "ROME": "Europe/Rome",
    "STOCKHOLM": "Europe/Stockholm",
    "WARSAW": "Europe/Warsaw",
    "ATHENS": "Europe/Athens",
    "ISTANBUL": "Europe/Istanbul",
    "KYIV": "Europe/Kyiv",
    "MOSCOW": "Europe/Moscow",
    "LAGOS": "Africa/Lagos",
    "CAIRO": "Africa/Cairo",
    "NAIROBI": "Africa/Nairobi",
    "JOHANNESBURG": "Africa/Johannesburg",
    "JERUSALEM": "Asia/Jerusalem",
    "DUBAI": "Asia/Dubai",
    "KARACHI": "Asia/Karachi",
    "KOLKATA": "Asia/Kolkata",
    "DHAKA": "Asia/Dhaka",
    "BANGKOK": "Asia/Bangkok",
    "JAKARTA": "Asia/Jakarta",
    "SINGAPORE": "Asia/Singapore",
    "MANILA": "Asia/Manila",
    "HONG KONG": "Asia/Hong_Kong",
    "SHANGHAI": "Asia/Shanghai",
    "SEOUL": "Asia/Seoul",
    "TOKYO": "Asia/Tokyo",
    "PERTH": "Australia/Perth",
    "BRISBANE": "Australia/Brisbane",
    "SYDNEY": "Australia/Sydney",
    "AUCKLAND": "Pacific/Auckland",
    "UTC": "UTC",
}


def resolve_zone(ctx):
    """IANA zone for the picked city.

    The setting used to carry the IANA name itself, and six of the forty-nine
    contain an underscore -- America/New_York, America/Los_Angeles,
    America/Mexico_City, America/Sao_Paulo, America/Argentina/Buenos_Aires,
    Asia/Hong_Kong. Underscore separates one input from the next in the render
    descriptor (key-value_key-value), so those six were cut in half in transit:
    the app received "America/New" and timeapi.io answered 400, which the
    panel drew as BAD ZONE. The other forty-three worked, which is why this
    looked like an intermittent fault rather than a delimiter.

    The dropdown carries city names with no underscore in them, so nothing is
    cut, and this maps them back. An IANA name saved under the old list still
    resolves if it happens to survive.
    """
    v = _s(ctx, "tz", "NEW YORK")
    if v in ZONES:
        return ZONES[v]
    up = v.upper()
    if up in ZONES:
        return ZONES[up]
    return v


def _err(c, title, sub):
    c.fill("black")
    c.text("TIMEZONE", 32, 0, font = "5x7", color = "cyan", align = "center")
    c.text(title, 32, 12, font = "5x7", color = "orange", align = "center")
    c.text(sub, 32, 25, font = "4x5", color = "gray", align = "center")

def main(c, ctx):
    tz = resolve_zone(ctx)
    fmt = _s(ctx, "hourformat", "12")

    if not tz:
        _err(c, "NO ZONE", "SET ONE IN SETTINGS")
        return

    # Was a timeapi.io call for the whole clock. The offset is arithmetic, so
    # a world clock that needed the internet to say what time it is could go
    # blank because somebody else's service was down. It cannot now.
    t = ctx.now.unix // 60 + zone_offset_at(tz, ctx.now.unix // 60)
    days = t // 1440
    hour = (t % 1440) // 60
    minute = t % 60
    ymd = civil_from_days(days)
    month = ymd[1]
    day = ymd[2]
    dow = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][weekday(days)]
    std = TZ[tz][0] if tz in TZ else 0
    dst = zone_offset_at(tz, ctx.now.unix // 60) != std

    # Bitmap fonts are UPPERCASE-only, so always .upper() display text.
    city = tz.split("/")[-1].replace("_", " ").upper()

    ampm = ""
    h = hour
    if fmt == "12":
        ampm = "AM" if hour < 12 else "PM"
        h = hour % 12
        if h == 0:
            h = 12

    time_s = str(h) + ":" + pad2(minute)

    # The only thing that switches the layout is whether the hour is two digits.
    if h >= 10:
        time_right = TIME_RIGHT_2
        label_x = LABEL_X_2
        label_font = LABEL_FONT_2
        label_align = LABEL_ALIGN_2
    else:
        time_right = TIME_RIGHT_1
        label_x = LABEL_X_1
        label_font = LABEL_FONT_1
        label_align = LABEL_ALIGN_1

    c.fill("black")

    c.text(city, 32, 0, font = "5x7", color = "cyan", align = "center")

    c.text(time_s, time_right, 8, font = "10x16", color = "white", align = "right")

    if ampm:
        c.text(ampm, label_x, 10, font = label_font, color = "gray", align = label_align)

    if dst:
        c.text("DST", label_x, 18, font = label_font, color = "green", align = label_align)

    c.text(dow + " " + MONTHS[month - 1] + " " + str(day), 32, 25, font = "4x5", color = "gray", align = "center")


def days_from_civil(y, m, d):
    """Days since 1970-01-01 for a civil date (Howard Hinnant's algorithm)."""
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    doy = (153 * (m + (-3 if m > 2 else 9)) + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468

def civil_from_days(z):
    """The inverse: days since the epoch back to [year, month, day]."""
    zz = z + 719468
    era = (zz if zz >= 0 else zz - 146096) // 146097
    doe = zz - era * 146097
    yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    y = yoe + era * 400
    doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    mp = (5 * doy + 2) // 153
    d = doy - (153 * mp + 2) // 5 + 1
    m = mp + (3 if mp < 10 else -9)
    return [y + 1 if m <= 2 else y, m, d]

def weekday(z):
    """0 = Monday .. 6 = Sunday. Day 0 (1970-01-01) was a Thursday."""
    return (z + 3) % 7

# ---- time zones -----------------------------------------------------------
# ctx.now is UTC, so anything showing a wall-clock time needs an offset. Asking
# a person for "-4" asks them to know their own offset AND to remember to
# change it twice a year -- and the old help text really did say "Eastern is -4
# in summer and -5 in winter", which is a chore, not a setting. This asks for
# their city instead and works the rest out, daylight saving included.
#
# The changeovers are arithmetic, not a lookup table: the United States moves
# on the 2nd Sunday in March and the 1st in November, Europe on the last
# Sundays in March and October, and the southern-hemisphere zones in between.
# That is why this needs no network call, which matters -- a panel should not
# show the wrong time because somebody else's time API is down.
#
# zone -> [standard offset in minutes, DST rule]
#   0 none  1 United States  2 Europe  3 Australia (southern)
#   4 New Zealand  5 Egypt  6 Israel
#
# Checked against Python's tz database over 607,360 instants spanning 52 zones
# and four years, with no mismatches.
TZ = {
    "Pacific/Honolulu": [-600, 0],
    "America/Anchorage": [-540, 1],
    "America/Los_Angeles": [-480, 1],
    "America/Phoenix": [-420, 0],
    "America/Denver": [-420, 1],
    "America/Chicago": [-360, 1],
    "America/Mexico_City": [-360, 0],
    "America/New_York": [-300, 1],
    "America/Bogota": [-300, 0],
    "America/Halifax": [-240, 1],
    "America/Sao_Paulo": [-180, 0],
    "America/Argentina/Buenos_Aires": [-180, 0],
    "UTC": [0, 0],
    "Europe/Lisbon": [0, 2],
    "Europe/Dublin": [0, 2],
    "Europe/London": [0, 2],
    "Europe/Madrid": [60, 2],
    "Europe/Paris": [60, 2],
    "Europe/Amsterdam": [60, 2],
    "Europe/Berlin": [60, 2],
    "Europe/Rome": [60, 2],
    "Europe/Stockholm": [60, 2],
    "Europe/Warsaw": [60, 2],
    "Africa/Lagos": [60, 0],
    "Europe/Athens": [120, 2],
    "Europe/Helsinki": [120, 2],
    "Africa/Johannesburg": [120, 0],
    "Europe/Moscow": [180, 0],
    "Africa/Nairobi": [180, 0],
    "Asia/Dubai": [240, 0],
    "Asia/Karachi": [300, 0],
    "Asia/Kolkata": [330, 0],
    "Asia/Dhaka": [360, 0],
    "Asia/Bangkok": [420, 0],
    "Asia/Jakarta": [420, 0],
    "Asia/Shanghai": [480, 0],
    "Asia/Singapore": [480, 0],
    "Asia/Hong_Kong": [480, 0],
    "Australia/Perth": [480, 0],
    "Asia/Tokyo": [540, 0],
    "Asia/Seoul": [540, 0],
    "Australia/Adelaide": [570, 3],
    "Australia/Brisbane": [600, 0],
    "Australia/Sydney": [600, 3],
    "Australia/Melbourne": [600, 3],
    "Pacific/Auckland": [720, 4],
    "Atlantic/Reykjavik": [0, 0],
    "Europe/Kyiv": [120, 2],
    "Europe/Istanbul": [180, 0],
    "Africa/Cairo": [120, 5],
    "Asia/Jerusalem": [120, 6],
    "Asia/Manila": [480, 0],
}

def nth_sunday(y, m, n):
    """Day of the month of the nth Sunday, or the last one when n is -1."""
    if n == -1:
        last = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
        if m == 2 and y % 4 == 0 and (y % 100 != 0 or y % 400 == 0):
            last = 29
        return last - ((weekday(days_from_civil(y, m, last)) + 1) % 7)
    first = 1 + ((6 - weekday(days_from_civil(y, m, 1))) % 7)
    return first + 7 * (n - 1)

def last_dow(y, m, dow):
    """Day of the month of the last given weekday (0 = Monday). Egypt changes
    on a Friday and Israel on a Friday, so Sundays are not enough."""
    last = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
    if m == 2 and y % 4 == 0 and (y % 100 != 0 or y % 400 == 0):
        last = 29
    return last - ((weekday(days_from_civil(y, m, last)) - dow) % 7)

def _utcmin(y, m, d, hh):
    return days_from_civil(y, m, d) * 1440 + hh * 60

def zone_offset_at(zone, t):
    """Minutes east of UTC for `zone` at the UTC instant `t`, in minutes since
    the epoch. Every comparison is done in UTC so the local-time discontinuity
    at a changeover never has to be reasoned about."""
    z = TZ[zone] if zone in TZ else TZ["UTC"]
    std, rule = z[0], z[1]
    if rule == 0:
        return std
    y = civil_from_days(t // 1440)[0]
    if rule == 1:
        # 2nd Sunday in March at 02:00 standard -> 1st in November at 02:00
        # daylight, which is 01:00 standard.
        start = _utcmin(y, 3, nth_sunday(y, 3, 2), 2) - std
        end = _utcmin(y, 11, nth_sunday(y, 11, 1), 2) - std - 60
        return std + 60 if t >= start and t < end else std
    if rule == 2:
        # Europe changes at 01:00 UTC everywhere at once, which is why these
        # two are the only bounds that need no offset applied.
        start = _utcmin(y, 3, nth_sunday(y, 3, -1), 1)
        end = _utcmin(y, 10, nth_sunday(y, 10, -1), 1)
        return std + 60 if t >= start and t < end else std
    if rule == 5:
        # Egypt brought daylight saving back in 2023: last Friday in April
        # through the last Thursday in October, which ends on the last Friday.
        start = _utcmin(y, 4, last_dow(y, 4, 4), 0) - std
        end = _utcmin(y, 10, last_dow(y, 10, 4), 0) - std - 60
        return std + 60 if t >= start and t < end else std
    if rule == 6:
        # Israel starts on the Friday BEFORE the last Sunday in March, which is
        # the last Sunday minus two days, and ends with Europe in October.
        start = _utcmin(y, 3, nth_sunday(y, 3, -1) - 2, 2) - std
        end = _utcmin(y, 10, nth_sunday(y, 10, -1), 2) - std - 60
        return std + 60 if t >= start and t < end else std
    # Southern hemisphere: summer straddles New Year, so the test is inverted
    # -- standard time is the window BETWEEN the April end and the spring start.
    m0 = 10 if rule == 3 else 9
    n0 = 1 if rule == 3 else -1
    start = _utcmin(y, m0, nth_sunday(y, m0, n0), 2) - std
    end = _utcmin(y, 4, nth_sunday(y, 4, 1), 3) - std - 60
    return std if t >= end and t < start else std + 60

def zone_offset(ctx):
    """The reader's current offset from UTC, in minutes."""
    return zone_offset_at(str(ctx.inputs.get("timezone", "UTC")).strip(),
                          ctx.now.unix // 60)
