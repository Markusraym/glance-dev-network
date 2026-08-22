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

# Todoist — what is actually due today, and how far behind you are.
#
# Auth is a PERSONAL API token, not OAuth: Todoist issues one from Settings >
# Integrations > Developer and it works as a plain bearer header. That matters
# because there is no browser here to run an OAuth dance in, and the token is
# what makes this app possible at all.
#
# Todoist numbers priority backwards from how it labels it: the API's
# `priority: 4` is the one the app calls P1. Everything below uses the API
# numbering and only the flag colours reveal the difference.

BRAND = "#E44332"      # Todoist red, for the tab and the brand mark
ALARM = "#FF3B30"      # a hotter red for overdue, so brand and alarm never fight
P2_C = "orange"
P3_C = "#3D8CFF"

API = "https://api.todoist.com/rest/v2/tasks"

# One shape system: a ring is still yours to do, a filled disc is final.
CB_OPEN = """
..###..
.#...#.
#.....#
#.....#
#.....#
.#...#.
..###..
"""
CB_DONE = """
..###..
.####C.
####C##
#C#C###
##C####
.#####.
..###..
"""
CB_LATE = """
..###..
.##!##.
###!###
###!###
#######
.##!##.
..###..
"""
FLAG = """
p###
p###
p###
p...
p...
p...
"""
MARK = """
..#########..
.###########.
#############
#############
#########WW##
########WW###
###WW##WW####
####WWWW#####
#####WW######
#############
#############
.###########.
..#########..
"""

def prio_color(p):
    if p >= 4:
        return ALARM
    if p == 3:
        return P2_C
    if p == 2:
        return P3_C
    return None            # P4 is "no priority"; drawing a flag for it is noise

DEMO_TASKS = [
    ["PAY RENT", 4, -3, 17 * 60],
    ["CALL DENTIST", 3, -1, -1],
    ["SHIP GLANCE ORDERS", 3, 0, 14 * 60],
    ["REVIEW PULL REQUESTS", 2, 0, 15 * 60 + 30],
    ["WATER THE PLANTS", 1, 0, -1],
    ["BOOK FLIGHTS", 2, 0, -1],
    ["EMAIL THE ACCOUNTANT", 1, 0, -1],
    ["TIDY THE WORKSHOP", 1, 0, -1],
    ["ORDER LED PANELS", 3, 0, 11 * 60],
]

def demo_state(today, now):
    tasks = []
    for t in DEMO_TASKS:
        day = today + t[2]
        tasks.append({"title": t[0], "prio": t[1], "day": day,
                      "mins": t[3], "late": today - day})
    return tasks

def read_tasks(ctx):
    offmin = parse_offset(ctx.inputs.get("utcoffset", "-4"))
    now = ctx.now.unix // 60 + offmin
    today = now // 1440
    base = {"state": "ok", "tasks": [], "now": now, "today": today,
            "done": 0, "demo": False}

    token = str(ctx.inputs.get("token", "")).strip()
    if token == "":
        base["demo"] = True
        base["tasks"] = demo_state(today, now)
        base["done"] = 5
        return sort_tasks(base)

    r = http.get(API, headers = {"Authorization": "Bearer " + token},
                 params = {"filter": "overdue | today"}, ttl_seconds = 300)
    code = r["status_code"]
    if code == 401 or code == 403:
        base["state"] = "denied"
        return base
    if code != 200 or r["json"] == None:
        base["state"] = "offline"
        return base

    rows = r["json"]
    if type(rows) != "list":
        base["state"] = "offline"
        return base
    for row in rows:
        if type(row) != "dict":
            continue
        title = str(get(row, "content", "")).strip().upper()
        if title == "":
            continue
        due = get(row, "due", {})
        stamp = get(due, "datetime", "") or get(due, "date", "")
        t = parse_iso(stamp, offmin)
        day = t // 1440 if t != None else today
        mins = (t % 1440) if (t != None and len(str(stamp)) > 10) else -1
        base["tasks"].append({"title": title, "prio": num(get(row, "priority", 1), 1),
                              "day": day, "mins": mins, "late": today - day})
    if len(base["tasks"]) == 0:
        base["state"] = "clear"
    return sort_tasks(base)

def sort_tasks(base):
    """Overdue oldest-first, then priority, then time of day, then untimed."""
    def key(t):
        overdue = 0 if t["late"] > 0 else 1
        return (overdue * 1000000 - t["late"] * 10000 +
                (4 - t["prio"]) * 2000 + (t["mins"] if t["mins"] >= 0 else 1439))
    base["tasks"] = sorted(base["tasks"], key = key)
    od = 0
    for t in base["tasks"]:
        if t["late"] > 0:
            od += 1
    base["overdue"] = od
    base["due"] = len(base["tasks"]) - od
    return base

def late_label(t, today):
    if t["late"] > 0:
        n = t["late"]
        return [str(n if n < 99 else 99) + "D LATE", ALARM]
    if t["mins"] >= 0:
        return [clock(t["day"] * 1440 + t["mins"], True, True), "amber"]
    return ["TODAY", "gray"]

def fail_screen(c, st):
    if st["state"] == "denied":
        rail(c, OFFLINE)
        message(c, "TOKEN REJECTED", "CHECK THE API TOKEN")
        return True
    if st["state"] == "offline":
        rail(c, OFFLINE)
        message(c, "TODOIST OFFLINE", "CANT REACH THE API")
        return True
    return False

def all_clear(c, st):
    rail(c, "green")
    c.sprite(MARK, 60, 11, legend = {"#": BRAND, "W": "white"})
    c.text("ALL CLEAR", 80, 11, font = "5x7", color = "white")
    c.text(str(st["done"]) + " DONE - NOTHING LEFT", 80, 22, font = "4x5",
           color = "gray")

# ------------------------------------------------------------ page 1: today
def today(c, ctx):
    c.fill("black")
    st = read_tasks(ctx)
    tab(c, "TODAY", BRAND)
    if fail_screen(c, st):
        return
    c.text(date_str(st["today"]), 190, 2, font = "4x5", color = "gray",
           align = "right")
    if st["state"] == "clear":
        all_clear(c, st)
        return

    rail(c, ALARM if st["overdue"] > 0 else ("amber" if st["due"] > 0 else "green"))
    if st["demo"]:
        c.text("DEMO", 46, 2, font = "4x5", color = "midgray")
    elif st["done"] > 0:
        c.text(str(st["done"]) + " DONE", 46, 2, font = "4x5", color = "midgray")

    # Two numbers, not one sum: "how underwater am I" should be a glance, and
    # overdue and due-today are completely different feelings.
    od = st["overdue"]
    c.text(str(od if od < 99 else 99), 6, 9, font = "10x16",
           color = ALARM if od > 0 else "green")
    c.text("OVERDUE", 6, 27, font = "4x5", color = ALARM if od > 0 else "green")
    due = st["due"]
    c.text(str(due if due < 99 else 99), 48, 9, font = "10x16", color = "white")
    c.text("TODAY", 48, 27, font = "4x5", color = "gray")
    c.vline(76, 9, 21, STRUCT)

    c.text("NEXT", 82, 9, font = "4x5", color = "gray")
    t = st["tasks"][0]
    lab = late_label(t, st["today"])
    c.text(lab[0], 190, 9, font = "4x5", color = lab[1], align = "right")
    if t["late"] > 0:
        c.sprite(CB_LATE, 82, 17, legend = {"#": ALARM, "!": "black"})
    else:
        c.sprite(CB_OPEN, 82, 17,
                 legend = {"#": ALARM if t["prio"] >= 4 else "gray"})
    tx = 92
    pc = prio_color(t["prio"])
    if pc != None:
        c.sprite(FLAG, 92, 17, legend = {"#": pc, "p": "#B0B0B0"})
        tx = 99
    c.text(clip_words(c, t["title"], "4x7", 190 - tx), tx, 17, font = "4x7",
           color = "white")

# ------------------------------------------------------------ page 2: tasks
def tasks(c, ctx):
    c.fill("black")
    st = read_tasks(ctx)
    tab(c, "TASKS", BRAND)
    if fail_screen(c, st):
        return
    if st["state"] == "clear":
        all_clear(c, st)
        return

    shown = st["tasks"][:3]
    hidden = st["tasks"][3:]
    hidden_late = 0
    for t in hidden:
        if t["late"] > 0:
            hidden_late += 1
    rail(c, ALARM if st["overdue"] > 0 else "amber")

    if len(hidden) > 0:
        n = len(hidden)
        c.text("+" + str(n if n < 99 else 99) + " MORE", 190, 2, font = "4x5",
               color = ALARM if hidden_late > 0 else "gray", align = "right")
    else:
        c.text("ALL SHOWN", 190, 2, font = "4x5", color = "midgray", align = "right")

    for i in range(len(shown)):
        t = shown[i]
        y = 8 + i * 8
        if t["late"] > 0:
            c.sprite(CB_LATE, 4, y, legend = {"#": ALARM, "!": "black"})
        else:
            c.sprite(CB_OPEN, 4, y,
                     legend = {"#": ALARM if t["prio"] >= 4 else "gray"})
        pc = prio_color(t["prio"])
        if pc != None:
            c.sprite(FLAG, 14, y, legend = {"#": pc, "p": "#B0B0B0"})
        lab = late_label(t, st["today"])
        lw = c.text_width(lab[0], "4x7")
        c.text(lab[0], 190, y, font = "4x7", color = lab[1], align = "right")
        c.text(clip_words(c, t["title"], "4x7", 190 - lw - 4 - 21), 21, y,
               font = "4x7", color = "white")

def date_str(day):
    cc = civil_from_days(day)
    return DOW[weekday(day)] + " " + MONTHS[cc[1] - 1] + " " + str(cc[2])
