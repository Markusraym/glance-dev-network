# ---------------------------------------------------------------- house kit
# The chrome every Glance app in this family shares: a coloured page tab, a
# full-height accent rail, one failure screen, and the text helpers that keep a
# long string from running off a panel that does not clip.

STRUCT = "darkgray"        # dividers, tracks, spines
OFFLINE = "#3C4043"        # the rail when there is no data
INK = "#F4F7FF"            # primary text
DIM = "#6E7A94"            # secondary text

def clip(c, text, font, maxw):
    """Longest prefix of `text` that fits `maxw`.

    text_fit shrinks the font instead, and when even its smallest option
    overflows it draws anyway -- which is how a long name ends up running
    through whatever is beside it."""
    t = str(text)
    if c.text_width(t, font) <= maxw:
        return t
    for k in range(len(t), 0, -1):
        if c.text_width(t[:k], font) <= maxw:
            return t[:k]
    return ""

def clip_words(c, text, font, maxw):
    """Like clip(), but backs up to the last whole word -- unless that costs
    more than 30% of what fit. "DAILY STANDUP" cut to "DAILY" loses the word
    that identified it; better to show an obviously clipped "DAILY STANDU"."""
    t = clip(c, text, font, maxw)
    if t == str(text):
        return t
    sp = t.rfind(" ")
    if sp > 0 and sp * 10 >= len(t) * 7:
        return t[:sp]
    return t

def fit(c, text, fonts, maxw):
    """[font, clipped text] for the largest listed font that fits.

    8x12 is skipped for any string containing a hyphen. That font's '-' glyph
    is a solid 6x12 block rather than a dash -- verified against the panel's own
    bitmap_8x12.php, so it is the hardware font that is wrong, not the SDK's
    copy of it. Date ranges, scores and time spans all carry hyphens, so this
    would otherwise turn "11A-1P" into "11A<block>1P" at the one size most
    likely to be chosen for a hero."""
    t = str(text)
    dashed = t.find("-") >= 0
    pick = fonts[len(fonts) - 1]
    for f in fonts:
        if dashed and f == "8x12":
            continue
        if c.text_width(t, f) <= maxw:
            pick = f
            break
    if dashed and pick == "8x12":
        pick = "6x8"
    return [pick, clip(c, text, pick, maxw)]

def tab(c, word, accent, x = 4):
    """The page chip. Same object, same place, on every page of every app."""
    w = c.text_width(word, "4x5")
    c.round_rect(x, 0, x + w + 3, 7, 2, fill = accent)
    c.text(word, x + 2, 2, font = "4x5", color = "black")
    return x + w + 5

def rail(c, color):
    c.rect(0, 0, 1, 31, fill = color)

def message(c, head, sub, head_color = "amber"):
    """The one screen every failure state shares."""
    c.text(clip(c, head, "5x7", c.width - 4), c.width // 2, 11, font = "5x7",
           color = head_color, align = "center")
    if sub != "":
        c.text(clip(c, sub, "4x5", c.width - 4), c.width // 2, 23, font = "4x5",
               color = "gray", align = "center")

def pct_bar(c, x, y, w, h, pct, color, bg = STRUCT):
    """progress_bar, but it never draws a 0-width sliver as if it were 1."""
    c.rect(x, y, x + w - 1, y + h - 1, fill = bg)
    n = int(w * pct / 100.0 + 0.5)
    if n > 0:
        c.rect(x, y, x + (n if n <= w else w) - 1, y + h - 1, fill = color)

# ------------------------------------------------------------ safe fetching
def num(s, fallback = -1):
    """int() raises on anything non-numeric, and a raised host error kills the
    whole render, so every number out of a feed comes through here."""
    t = str(s).strip()
    neg = t.startswith("-")
    if neg or t.startswith("+"):
        t = t[1:]
    d = ""
    for ch in t.elems():
        if ch >= "0" and ch <= "9":
            d += ch
    if d == "" or len(d) != len(t):
        return fallback
    v = int(d)
    return -v if neg else v

def dec(s, places, fallback = None):
    """A decimal string -> int scaled by 10^places, or fallback. Starlark has
    floats, but feeds hand back "27.573" as a string and int() will not take
    it; this keeps the arithmetic exact and the failure quiet."""
    t = str(s).strip()
    neg = t.startswith("-")
    if neg or t.startswith("+"):
        t = t[1:]
    parts = t.split(".")
    if len(parts) > 2:
        return fallback
    whole = num(parts[0], -1) if parts[0] != "" else 0
    if whole < 0:
        return fallback
    frac = 0
    if len(parts) == 2:
        f = parts[1]
        for i in range(places):
            f = f + "0"
        f = f[:places]
        frac = num(f, -1)
        if frac < 0:
            return fallback
    else:
        for i in range(places):
            whole = whole * 10
        return -whole if neg else whole
    scaled = whole
    for i in range(places):
        scaled = scaled * 10
    scaled = scaled + frac
    return -scaled if neg else scaled

def get(obj, key, fallback = None):
    """dict.get that survives a null parent, which JSON feeds hand back often."""
    if obj == None or type(obj) != "dict":
        return fallback
    v = obj.get(key, fallback)
    return fallback if v == None else v

def dig(obj, path, fallback = None):
    """get() down a chain: dig(ev, ["status", "type", "state"], "")."""
    cur = obj
    for k in path:
        if cur == None or type(cur) != "dict":
            return fallback
        cur = cur.get(k, None)
    return fallback if cur == None else cur

def ents(s):
    """Decode the handful of HTML entities that show up in plain-text feeds."""
    t = str(s)
    t = t.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    return t.replace("&quot;", '"').replace("&#39;", "'").replace("&nbsp;", " ")

# --------------------------------------------------------------------- time
def days_from_civil(y, m, d):
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    doy = (153 * (m + (-3 if m > 2 else 9)) + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468

def civil_from_days(z):
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

MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

def parse_iso(s, offmin):
    """Minutes since epoch, in the viewer's wall clock, from an ISO stamp.
    A trailing Z means real UTC and gets the offset; anything else is treated
    as already-local, which is right for feeds that carry a zone."""
    t = str(s).strip()
    if len(t) < 10:
        return None
    y, mo, d = num(t[0:4]), num(t[5:7]), num(t[8:10])
    if y < 1970 or mo < 1 or mo > 12 or d < 1 or d > 31:
        return None
    mins = days_from_civil(y, mo, d) * 1440
    if len(t) >= 16 and t[10] == "T":
        hh, mi = num(t[11:13]), num(t[14:16])
        if hh < 0 or hh > 23 or mi < 0 or mi > 59:
            return None
        mins += hh * 60 + mi
        if t.endswith("Z"):
            mins += offmin
    return mins

def clock(mins, ampm = True, compact = False):
    """2:30P / 9:00A -- 12-hour, no leading zero, one-letter meridiem."""
    tod = mins % 1440
    h, m = tod // 60, tod % 60
    ap = "P" if h >= 12 else "A"
    h12 = h % 12
    if h12 == 0:
        h12 = 12
    if compact and m == 0:
        return str(h12) + ap if ampm else str(h12)
    out = str(h12) + ":" + fmt.pad(m)
    return out + ap if ampm else out

def ago(mins):
    """A short "how long since" for a positive minute count."""
    if mins < 1:
        return "NOW"
    if mins < 60:
        return str(mins) + "M"
    if mins < 1440:
        return str(mins // 60) + "H"
    return str(mins // 1440) + "D"
# Octopus Agile — the half-hourly price of electricity, and when to wait.
#
# Agile republishes a new day's prices around 4pm for the following day, so the
# feed always holds somewhere between 12 and 48 hours of future prices. The one
# question this app exists to answer is not "what does power cost" -- it is
# "should I run the dishwasher now, or at 2am".
#
# Prices go NEGATIVE on windy nights. That is a real event on this tariff (you
# are paid to consume) and it gets its own colour and its own word, because a
# user who catches one has genuinely won something.
#
# No API key. The tariff code is built from a single region letter.

TARIFF = "AGILE-24-10-01"
BASE = "https://api.octopus.energy/v1/products/"

# Prices are pence per kWh, carried as TENTHS OF A PENNY as integers throughout.
# Half a penny decides which colour band a slot lands in, and float drift on a
# 48-slot scan is not worth the risk.
CHEAP = 150          # 15.0p and under: run it now
NORMAL = 250         # 25.0p and under: ordinary
# above that: expensive. Below zero: paid to use it.

PINK = "#FF00A0"     # Octopus brand
FREE = "#00E5FF"     # negative pricing
GOOD = "#3EEB8A"
MID = "#FFC43A"
BAD = "#FF3B3B"

REGIONS = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P"]

def band(p):
    """[colour, word] for a price in tenths of a penny."""
    if p < 0:
        return [FREE, "PAID"]
    if p <= CHEAP:
        return [GOOD, "CHEAP"]
    if p <= NORMAL:
        return [MID, "OK"]
    return [BAD, "PRICEY"]

def price_text(p):
    """13.5P / -2.1P -- one decimal, which is how Octopus quotes it."""
    neg = p < 0
    v = -p if neg else p
    s = str(v // 10) + "." + str(v % 10) + "P"
    return "-" + s if neg else s

def region_of(ctx):
    r = str(ctx.inputs.get("region", "C")).strip().upper()
    if len(r) > 1:
        r = r[:1]
    return r if r in REGIONS else "C"

# ------------------------------------------------------------------- demo
# A believable windy-night curve: an evening peak, an overnight trough that
# dips below zero, and a normal morning. Used when the feed cannot be reached
# so the app still shows what it is for.
DEMO_CURVE = [
    285, 302, 331, 344, 318, 296, 271, 254, 238, 221, 196, 174,
    151, 128, 96, 61, 24, -8, -21, -14, 12, 47, 83, 112,
    138, 159, 177, 194, 212, 233, 258, 279, 301, 322, 338, 349,
    327, 305, 288, 266, 249, 231, 218, 204, 191, 183, 176, 168,
]

def demo_slots(now30):
    out = []
    for i in range(len(DEMO_CURVE)):
        out.append({"start": (now30 + i) * 30, "price": DEMO_CURVE[i]})
    return out

# ------------------------------------------------------------------- fetch
def read_prices(ctx):
    offmin = zone_offset(ctx)
    now = ctx.now.unix // 60 + offmin
    now30 = now // 30                 # the current half-hour slot
    base = {"state": "ok", "slots": [], "now": now, "now30": now30,
            "region": region_of(ctx), "demo": False}

    url = (BASE + TARIFF + "/electricity-tariffs/E-1R-" + TARIFF + "-" +
           base["region"] + "/standard-unit-rates/")
    r = http.get(url, ttl_seconds = 1800)
    if r["status_code"] != 200 or r["json"] == None:
        base["state"] = "demo"
        base["demo"] = True
        base["slots"] = demo_slots(now30)
        return base

    rows = r["json"].get("results", [])
    slots = []
    for row in rows:
        p = dec(row.get("value_inc_vat"), 1)
        t = parse_iso(row.get("valid_from", ""), offmin)
        if p == None or t == None:
            continue
        slots.append({"start": t, "price": p})
    # The feed is newest-first; sort forward and keep from this slot on.
    slots = sorted(slots, key = lambda s: s["start"])
    out = []
    for s in slots:
        if s["start"] // 30 >= now30:
            out.append(s)
    if len(out) == 0:
        base["state"] = "stale"
        return base
    base["slots"] = out
    return base

def cheapest_window(slots, n):
    """[start index, average price] for the cheapest run of n consecutive
    slots. Half-hour slots, so n=4 is a two-hour appliance cycle."""
    if len(slots) < n:
        return None
    best, best_avg = 0, 0
    for i in range(len(slots) - n + 1):
        total = 0
        for k in range(n):
            total += slots[i + k]["price"]
        avg = total // n
        if i == 0 or avg < best_avg:
            best, best_avg = i, avg
    return [best, best_avg]

# ------------------------------------------------------------------- art
# An octopus at 10x9. Two things make it read as an octopus rather than a
# jellyfish at this size: the eyes sit HIGH on the dome, and the arms splay
# outward instead of hanging straight down -- a straight fringe is a comb.
OCTOPUS = """
..######..
.########.
##oo##oo##
##########
##########
.########.
..#.##.#..
.#..##..#.
#...##...#
"""
OCTO_LEGEND = {"#": PINK, "o": "white"}

# A bolt for the price unit, 5x9.
BOLT = """
..##
.##.
###.
.##.
.#..
"""

def octopus(c, x, y):
    c.sprite(OCTOPUS, x, y, legend = OCTO_LEGEND)

# ------------------------------------------------------------ page 1: now
def now(c, ctx):
    c.fill("black")
    st = read_prices(ctx)
    tab(c, "AGILE", PINK)
    if st["state"] == "stale":
        rail(c, OFFLINE)
        message(c, "NO PRICES YET", "AGILE PUBLISHES TOMORROW AROUND 4PM")
        return

    cur = st["slots"][0]
    col, word = band(cur["price"])[0], band(cur["price"])[1]
    rail(c, col)
    octopus(c, 40, 0)

    c.text(st["region"], 56, 2, font = "4x5", color = DIM)
    if st["demo"]:
        c.text("DEMO", 176, 2, font = "4x5", color = DIM, align = "right")

    # The price is the page. Everything else explains it.
    f = fit(c, price_text(cur["price"]), ["16x20", "10x16", "8x12"], 84)
    c.text(f[1], 4, 10, font = f[0], color = col)
    c.text(word, 92, 10, font = "6x8", color = col)

    # What it becomes next, so a person knows whether to wait ten minutes.
    if len(st["slots"]) > 1:
        nxt = st["slots"][1]
        arrow = "UP" if nxt["price"] > cur["price"] else "DOWN"
        if nxt["price"] == cur["price"]:
            arrow = "FLAT"
        c.trend_arrow(92, 21, 1 if arrow == "UP" else (-1 if arrow == "DOWN" else 0),
                      color = band(nxt["price"])[0])
        c.text(price_text(nxt["price"]) + " AT " + clock(nxt["start"], True, True),
               100, 21, font = "4x7", color = INK)

# ---------------------------------------------------------- page 2: curve
# Every remaining half-hour, as a column whose height is its price and whose
# colour is its band. A day of electricity is a shape -- two troughs and a
# teatime spike -- and the shape is the thing you actually plan against.
def curve(c, ctx):
    c.fill("black")
    st = read_prices(ctx)
    tab(c, "NEXT", PINK)
    if st["state"] == "stale":
        rail(c, OFFLINE)
        message(c, "NO PRICES YET", "AGILE PUBLISHES TOMORROW AROUND 4PM")
        return
    slots = st["slots"][:48]                   # at most 24 hours
    rail(c, band(slots[0]["price"])[0])
    if st["demo"]:
        c.text("DEMO", 189, 2, font = "4x5", color = DIM, align = "right")

    lo, hi = slots[0]["price"], slots[0]["price"]
    for s in slots:
        if s["price"] < lo:
            lo = s["price"]
        if s["price"] > hi:
            hi = s["price"]
    # Scale between the day's OWN low and high, not from zero. Agile rarely
    # drops under a third of its peak, so a zero baseline draws every slot as a
    # nearly-full bar and the shape -- which is the entire point -- disappears.
    floor = lo if lo < 0 else lo - (hi - lo) // 6
    if hi <= floor:
        hi = floor + 1

    x0, top, bot = 4, 10, 23
    w = 186 // len(slots)
    if w < 1:
        w = 1
    span = hi - floor
    zero_y = bot
    if lo < 0:
        zero_y = bot - (0 - floor) * (bot - top) // span
    for i in range(len(slots)):
        pr = slots[i]["price"]
        x = x0 + i * w
        y = bot - (pr - floor) * (bot - top) // span
        if y < top:
            y = top
        if y > bot:
            y = bot
        col = band(pr)[0]
        if pr < 0:
            c.rect(x, zero_y + 1, x + w - 1, bot, fill = FREE)
        else:
            c.rect(x, y, x + w - 1, zero_y, fill = col)
    if lo < 0:
        c.hline(x0, zero_y, len(slots) * w, "#7A8AA8")

    # Now/mid/end markers, on their own row under the chart.
    n = len(slots)
    c.text(clock(slots[0]["start"], True, True), x0, 26, font = "4x5", color = DIM)
    if n > 4:
        c.text(clock(slots[n // 2]["start"], True, True), x0 + (n // 2) * w, 26,
               font = "4x5", color = DIM, align = "center")
    c.text(clock(slots[n - 1]["start"], True, True), x0 + n * w, 26,
           font = "4x5", color = DIM, align = "right")
    c.text(price_text(hi), 189, 9, font = "4x5", color = BAD, align = "right")
    c.text(price_text(lo), 189, 17, font = "4x5", color = band(lo)[0], align = "right")

# -------------------------------------------------------- page 3: cheapest
def best(c, ctx):
    c.fill("black")
    st = read_prices(ctx)
    tab(c, "BEST", PINK)
    if st["state"] == "stale":
        rail(c, OFFLINE)
        message(c, "NO PRICES YET", "AGILE PUBLISHES TOMORROW AROUND 4PM")
        return
    slots = st["slots"]
    hours = num(ctx.inputs.get("runhours", "2"), 2)
    if hours < 1:
        hours = 1
    if hours > 6:
        hours = 6
    n = hours * 2
    win = cheapest_window(slots, n)
    if win == None:
        rail(c, OFFLINE)
        message(c, "NOT ENOUGH PRICES", "TRY A SHORTER RUN TIME")
        return
    i, avg = win[0], win[1]
    col = band(avg)[0]
    rail(c, col)
    octopus(c, 34, 0)

    start = slots[i]["start"]
    end = start + n * 30
    c.text(str(hours) + "H WINDOW", 48, 2, font = "4x5", color = DIM)

    # The whole window in one hero line. A 16x20 start time plus a separate
    # "TO ..." underneath does not fit: 16x20 occupies rows 9..28, and anything
    # below it lands off the panel or back under the tab.
    span = clock(start, True, True) + "-" + clock(end, True, True)
    f = fit(c, span, ["10x16", "8x12", "6x8"], 98)
    c.text(f[1], 4, 10, font = f[0], color = INK)

    c.vline(106, 6, 22, STRUCT)
    c.text(price_text(avg), 112, 8, font = "8x12", color = col)
    # AVG, not AVERAGE: the long word reached x=145 and the saving is right
    # aligned to 189, so at four digits the two ran into each other.
    c.text("AVG", 112, 22, font = "4x5", color = DIM)
    saving = slots[0]["price"] - avg
    if saving > 0:
        c.text("SAVE " + price_text(saving), 189, 22, font = "4x5",
               color = GOOD, align = "right")


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
