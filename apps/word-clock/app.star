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

def intpart(s, fallback = 0):
    """Whole-number part of a value that may arrive as a decimal.

    ADS-B ground speed comes back as 275.5 and altitude as 4600, from the same
    feed. num() rejects anything with a dot, so reading gs with it turned every
    aircraft's speed into 0 -- a wrong number that looks like a real one."""
    t = str(s).strip()
    return num(t.split(".")[0], fallback)

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

def parse_offset(raw):
    """Hours from UTC, as minutes. Free text, so "EST" lands here too."""
    t = str(raw).strip()
    neg = t.startswith("-")
    if neg or t.startswith("+"):
        t = t[1:]
    t = t.split(":")[0].split(".")[0].strip()
    d = ""
    for ch in t.elems():
        if ch >= "0" and ch <= "9":
            d += ch
    if d == "":
        return 0
    h = int(d)
    if h > 14:
        h = 14
    return (-h if neg else h) * 60

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

# ---- word clock -----------------------------------------------------------
# A QLOCKTWO in landscape. The alternative was a typographic setting, which
# solves the 10-versus-37-character problem by changing font size -- and a
# clock whose type jumps between sizes every five minutes reads as a status
# ticker, not an object. The matrix dissolves the problem instead: the frame is
# eternal, every phrase costs exactly the same, and the charm of the original
# (a field of letters out of which the time emerges) survives the move to
# 192x32 as a wide four-row grid.
#
# Nobody has seen a landscape QLOCKTWO, so it reads as an homage rather than a
# knock-off.
#
# Dropping MINUTES from the phrasing is part of that commitment. Pure QLOCKTWO
# says IT IS TWENTYFIVE PAST ELEVEN, so the 37-character phrase simply ceases
# to exist and every line fits the grid it was built for.

# 31 columns by 4 rows of 5x7. Row 0 is notched -- it starts at column 7, which
# is where the tab chip stops. The letters that are not part of any word are
# not random: read in order, r0c9, r0c12, r0c23, r1c4, r1c8 and r1c13 spell
# G-L-A-N-C-E, and they never light.
ROWS = [
    "ITGISLTWENTYFIVEAQUARTER",
    "HALFNTENCPASTETORBSEVENINEKDSIX",
    "THREEIGHTENUTWELVEMANOONEXEFOUR",
    "TWOAFIVERELEVENSOCLOCKBMIDNIGHT",
]
ROW0_COL = 7

# word -> [row, first column, last column]. Overlaps are deliberate and safe
# because only one of an overlapping pair can ever be lit: TWENTY and FIVE sit
# inside TWENTYFIVE, SEVEN and NINE share their N, THREE/EIGHT/TEN share twice,
# and ONE lives inside NOON.
W = {
    "IT": [0, 7, 8], "IS": [0, 10, 11],
    "TWENTY": [0, 13, 18], "FIVEM": [0, 19, 22], "TWENTYFIVE": [0, 13, 22],
    "QUARTER": [0, 24, 30],
    "HALF": [1, 0, 3], "TENM": [1, 5, 7], "PAST": [1, 9, 12], "TO": [1, 14, 15],
    "SEVEN": [1, 18, 22], "NINE": [1, 22, 25], "SIX": [1, 28, 30],
    "THREE": [2, 0, 4], "EIGHT": [2, 4, 8], "TEN": [2, 8, 10],
    "TWELVE": [2, 12, 17], "NOON": [2, 20, 23], "ONE": [2, 22, 24],
    "FOUR": [2, 27, 30],
    "TWO": [3, 0, 2], "FIVE": [3, 4, 7], "ELEVEN": [3, 9, 14],
    "OCLOCK": [3, 16, 21], "MIDNIGHT": [3, 23, 30],
}
HOURS = ["TWELVE", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN",
         "EIGHT", "NINE", "TEN", "ELEVEN"]

DAY = {"ink": "#F4F7FF", "ghost": "#2A3140", "accent": "#E8B04B",
       "dot": "#1B212C"}
NIGHT = {"ink": "#6E7A94", "ghost": "", "accent": "#7A5A26", "dot": ""}

def hour_word(h24, landmark):
    """The hour, as a word. On the TO side the destination 12:00 is NOON and
    00:00 is MIDNIGHT, because you anticipate a landmark -- FIVE TO MIDNIGHT.
    On the PAST side you have already rolled into an ordinary hour, so it is
    HALF PAST TWELVE. That asymmetry is how English is actually spoken, and it
    is what keeps TWELVE earning its cells."""
    h = h24 % 24
    if landmark:
        if h == 12:
            return "NOON"
        if h == 0:
            return "MIDNIGHT"
    return HOURS[h % 12]

def phrase(h, m):
    """The words to light for a wall-clock time."""
    slot = (m // 5) * 5
    lit = ["IT", "IS"]
    if slot == 0:
        w = hour_word(h, True)
        lit.append(w)
        if w != "NOON" and w != "MIDNIGHT":
            lit.append("OCLOCK")
        return lit
    if slot <= 30:
        lit.append(["", "FIVEM", "TENM", "QUARTER", "TWENTY", "TWENTYFIVE",
                    "HALF"][slot // 5])
        lit.append("PAST")
        lit.append(hour_word(h, False))
        return lit
    lit.append(["TWENTYFIVE", "TWENTY", "QUARTER", "TENM", "FIVEM"][slot // 5 - 7])
    lit.append("TO")
    lit.append(hour_word(h + 1, True))
    return lit

def is_night(ctx):
    s = num(ctx.inputs.get("nightstart", "22"), 22)
    e = num(ctx.inputs.get("nightend", "7"), 7)
    if s < 0 or s > 23:
        s = 22
    if e < 0 or e > 23:
        e = 7
    h = ctx.now.hour
    if s == e:
        return False
    if s < e:
        return h >= s and h < e
    return h >= s or h < e

def clock(c, ctx):
    c.fill("black")
    night = is_night(ctx)
    pal = NIGHT if night else DAY
    rail(c, pal["accent"])
    tab(c, "CLOCK", pal["accent"])

    lit = phrase(ctx.now.hour, ctx.now.minute)
    on = {}
    for name in lit:
        if name in W:
            spec = W[name]
            for col in range(spec[1], spec[2] + 1):
                on[spec[0] * 100 + col] = True

    for r in range(4):
        row = ROWS[r]
        base = ROW0_COL if r == 0 else 0
        y = 1 + r * 8
        for i in range(len(row)):
            col = base + i
            hot = (r * 100 + col) in on
            if not hot and pal["ghost"] == "":
                # At night the field goes out entirely and only the sentence
                # floats on black. Minimum light in a bedroom, still legible.
                continue
            c.text(row[i], 4 + 6 * col, y, font = "5x7",
                   color = pal["ink"] if hot else pal["ghost"])

    # Four dots down the right edge carry the remainder, so the clock is
    # minute-accurate without breaking the five-minute poetry.
    rem = ctx.now.minute % 5
    for k in range(4):
        col = pal["accent"] if k < rem else pal["dot"]
        if col == "":
            continue
        c.rect(190, 3 + k * 8, 191, 4 + k * 8, fill = col)
