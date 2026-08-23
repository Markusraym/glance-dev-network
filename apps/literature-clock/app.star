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

# ---- lowercase typesetting ------------------------------------------------
# 5x5 is the only panel font with real lowercase, which makes it the only font
# that can set a sentence rather than shout one. Two things about it have to be
# worked around before it can hold prose, and both were measured against
# gdn/data/fonts.json rather than guessed:
#
#   1. IT HAS NO PROSE PUNCTUATION. The whole charset is
#      " $%+-.0123456789:A-Za-z" -- no comma, apostrophe, quote, question mark,
#      exclamation, semicolon or parenthesis. c.text() skips a glyph it does
#      not have at zero width and says nothing, so "Don't" comes out "Dont"
#      and a question loses its question mark. Every one of those is stamped
#      here as raw pixels instead.
#
#   2. ITS PUNCTUATION AND SPACES ARE FULL WIDTH. The letters are properly
#      proportional -- "i" is 1px, "a" is 3, "m" is 5 -- but ".", ":", "-" and
#      " " are all 5px with the mark floating in the middle. A period costing
#      6px of advance wrecks the texture of a line and throws away about five
#      characters of measure. The space is set to 4 and the marks are stamped
#      at their true width.
#
# Descenders are the third fact: "g j p q y" are 7 rows tall against 5 for
# everything else, top-aligned with the tail hanging below the baseline. Line
# pitch has to be 8 or a descender lands on the next line's capitals.

# char -> [width, [[x, y], ...]] with y measured from the top of the 7-row cell
# and the baseline at row 4, matching the font's own alignment.
MICRO = {
    ".": [1, [[0, 4]]],
    ",": [1, [[0, 4], [0, 5]]],
    "'": [1, [[0, 0], [0, 1]]],
    "\"": [3, [[0, 0], [0, 1], [2, 0], [2, 1]]],
    ":": [1, [[0, 1], [0, 3]]],
    ";": [1, [[0, 1], [0, 4], [0, 5]]],
    "!": [1, [[0, 0], [0, 1], [0, 2], [0, 4]]],
    "?": [3, [[0, 0], [1, 0], [2, 0], [2, 1], [1, 2], [1, 4]]],
    "-": [3, [[0, 2], [1, 2], [2, 2]]],
    "(": [2, [[1, 0], [0, 1], [0, 2], [0, 3], [1, 4]]],
    ")": [2, [[0, 0], [1, 1], [1, 2], [1, 3], [0, 4]]],
}
SPACE_ADV = 4

# Everything 5x5 can draw that is NOT overridden above. Anything outside this
# set and MICRO is dropped, which is what keeps a stray accented character or a
# multi-byte sequence from becoming an invisible hole in a line.
GLYPHS = ("0123456789" +
          "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
          "abcdefghijklmnopqrstuvwxyz" +
          "$%+")

def prose_adv(c, ch):
    if ch == " ":
        return SPACE_ADV
    if ch in MICRO:
        return MICRO[ch][0] + 1
    if GLYPHS.find(ch) >= 0:
        return c.text_width(ch, "5x5") + 1
    return 0

def prose_w(c, s):
    """Width of a line as it will actually be drawn, trailing gap removed."""
    w = 0
    for ch in str(s).elems():
        w += prose_adv(c, ch)
    return w - 1 if w > 0 else 0

def prose_draw(c, x, y, s, col):
    """Draw a line, one character at a time, and return where it ended."""
    cx = x
    for ch in str(s).elems():
        if ch == " ":
            cx += SPACE_ADV
        elif ch in MICRO:
            m = MICRO[ch]
            for p in m[1]:
                c.pixel(cx + p[0], y + p[1], col)
            cx += m[0] + 1
        elif GLYPHS.find(ch) >= 0:
            c.text(ch, cx, y, font = "5x5", color = col)
            cx += c.text_width(ch, "5x5") + 1
    return cx

def normalise(s):
    """Curly quotes and long dashes into the ASCII the stamps cover."""
    t = str(s)
    for pair in [["’", "'"], ["‘", "'"], ["“", "\""],
                 ["”", "\""], ["—", "-"], ["–", "-"],
                 ["…", "..."], [" ", " "]]:
        t = t.replace(pair[0], pair[1])
    out = ""
    for ch in t.elems():
        if ch == " " or ch in MICRO or GLYPHS.find(ch) >= 0:
            out += ch
    # Collapse the runs of space that dropping characters can leave behind.
    for _ in range(4):
        out = out.replace("  ", " ")
    return out.strip()

def _join(words, a, b):
    out = ""
    for i in range(a, b):
        out = words[i] if out == "" else out + " " + words[i]
    return out

def balance(c, words, maxw, n):
    """Split `words` into exactly n lines, none wider than maxw, choosing the
    partition with the narrowest widest line and then the smallest spread.

    Greedy wrapping is what makes a short sentence look like a mistake: it
    fills line one to the edge and leaves one orphaned word underneath. This
    costs a triple loop over at most a dozen words and it is the whole
    difference between "measured" and "broken"."""
    if n < 1 or n > len(words):
        return None
    best, score = None, -1
    if n == 1:
        w = prose_w(c, _join(words, 0, len(words)))
        return [_join(words, 0, len(words))] if w <= maxw else None
    if n == 2:
        for i in range(1, len(words)):
            a, b = _join(words, 0, i), _join(words, i, len(words))
            wa, wb = prose_w(c, a), prose_w(c, b)
            if wa > maxw or wb > maxw:
                continue
            hi = wa if wa > wb else wb
            lo = wa if wa < wb else wb
            s = hi * 1000 + (hi - lo)
            if score < 0 or s < score:
                score, best = s, [a, b]
        return best
    for i in range(1, len(words) - 1):
        for j in range(i + 1, len(words)):
            a = _join(words, 0, i)
            b = _join(words, i, j)
            d = _join(words, j, len(words))
            wa, wb, wd = prose_w(c, a), prose_w(c, b), prose_w(c, d)
            if wa > maxw or wb > maxw or wd > maxw:
                continue
            hi = wa
            if wb > hi:
                hi = wb
            if wd > hi:
                hi = wd
            lo = wa
            if wb < lo:
                lo = wb
            if wd < lo:
                lo = wd
            s = hi * 1000 + (hi - lo)
            if score < 0 or s < score:
                score, best = s, [a, b, d]
    return best

def hang_x(c, line, width):
    """Centre a line on `width`, measuring WITHOUT a trailing full stop.

    A period is one pixel of ink and five of advance in a centred line; letting
    it count pushes the words visibly left of centre. Question and exclamation
    marks are not hung -- they carry as much weight as a letter."""
    core = line
    if core.endswith("."):
        core = core[:len(core) - 1]
    return (width - prose_w(c, core)) // 2

# ---- literature clock -----------------------------------------------------
# The current minute, as a passage from a novel that names that exact time.
#
# There is no digital clock anywhere in this app and there never will be. The
# prose IS the clock; putting a fallback time on the panel would say out loud
# that the conceit had failed. When a minute has no passage the app reaches
# back a few minutes instead, so the wall runs a little slow rather than blank.
#
# The dataset splits every quote into the words before the time, the words that
# ARE the time, and the words after -- which is what lets the clock glow amber
# inside white prose without any parsing on this end.

LIT = ("https://raw.githubusercontent.com/JohsEnevoldsen/" +
       "literature-clock/master/docs/times/")

AMBER = "#FFB000"

def strip_tags(t):
    """The dataset carries literal HTML. quote_first for 22:08 contains
    "<br/>", and since normalise() drops the angle brackets as undrawable the
    letters "br" survived into the middle of a Graham Greene sentence. Tags go
    before the character filter, and become a space, because that is what a
    line break means in running prose."""
    out = str(t)
    for _ in range(8):
        i = out.find("<")
        if i < 0:
            return out
        j = out.find(">", i)
        if j < 0:
            return out[:i]
        out = out[:i] + " " + out[j + 1:]
    return out

def norm_edge(s):
    """normalise(), but the leading and trailing spaces SURVIVE.

    normalise() strips, which is right for a standalone sentence and wrong
    here. quote_first is "She looked at her watch: " WITH the trailing space,
    and losing it renders "It washalf-past two" -- the words run straight into
    the clock. Whether the source put a space against the time phrase is real
    information about the sentence, and it is what decides whether the last
    word glues into the unbreakable token or stays its own."""
    t = strip_tags(s)
    core = normalise(t)
    if core == "":
        return ""
    lead = " " if t.startswith(" ") else ""
    trail = " " if t.endswith(" ") else ""
    return lead + core + trail

def fetch_minute(h, m):
    r = http.get(LIT + fmt.pad(h, 2) + "_" + fmt.pad(m, 2) + ".json",
                 ttl_seconds = 3600)
    if r["status_code"] != 200 or r["json"] == None:
        return None
    j = r["json"]
    if type(j) != "list" or len(j) == 0:
        return None
    return j

def read_lit(ctx):
    st = {"state": "ok", "q": None, "late": 0}
    h, m = ctx.now.hour, ctx.now.minute
    # Walk back a few minutes rather than showing nothing. Six is enough to
    # cover the dataset's gaps without the wall being noticeably wrong.
    for back in range(7):
        mm = m - back
        hh = h
        if mm < 0:
            mm += 60
            hh = (hh - 1) % 24
        j = fetch_minute(hh, mm)
        if j == None:
            continue
        pool, short = [], []
        for q in j:
            if type(q) != "dict" or str(get(q, "sfw", "yes")).lower() == "no":
                continue
            pool.append(q)
            # Some entries carry a whole paragraph of lead-in. Those survive
            # the fit only by having everything before the clock thrown away,
            # which leaves the panel showing a bare time in amber -- correct,
            # but a waste when a shorter passage is sitting in the same file.
            # 11:43 has exactly that pair.
            n = (len(str(get(q, "quote_first", ""))) +
                 len(str(get(q, "quote_time_case", ""))) +
                 len(str(get(q, "quote_last", ""))))
            if n <= 200:
                short.append(q)
        if len(short) > 0:
            pool = short
        if len(pool) == 0:
            continue
        # Stable within the minute, different from one day to the next.
        seed = (ctx.now.year * 10000 + ctx.now.month * 100 + ctx.now.day) * 1440
        pick = pool[(seed + hh * 60 + mm) % len(pool)]
        st["q"] = {
            "first": norm_edge(get(pick, "quote_first", "")),
            "time": normalise(strip_tags(get(pick, "quote_time_case", ""))),
            "last": norm_edge(get(pick, "quote_last", "")),
            "title": str(get(pick, "title", "")).upper(),
            "author": str(get(pick, "author", "")).upper(),
        }
        st["late"] = back
        return st
    st["state"] = "offline"
    return st

# ---- token model ----------------------------------------------------------
# A token is a list of [text, is_accent] segments. Splitting happens ONLY at
# spaces that belong to the ink text, which is the entire guarantee that the
# time phrase never breaks across a line: its internal spaces are accent
# spaces, so they are not split points, and punctuation touching it with no
# space in between glues into the same token rather than orphaning onto the
# next line.

# tok_w() drops the trailing 1px gap after a token's last character, and
# prose_draw() puts that gap back before the word space. So two tokens side by
# side cost tok_w + SPACE_ADV + 1 + tok_w, not tok_w + SPACE_ADV. Getting that
# wrong under-measures a line by one pixel per word, which on a nine-word line
# is eight pixels and ran the prose straight off the right edge of the panel.
WORD_GAP = SPACE_ADV + 1

def tok_w(c, tok):
    w = 0
    for seg in tok:
        if seg[0] != "":
            w += prose_w(c, seg[0]) + 1
    return w - 1 if w > 0 else 0

def tok_txt(tok):
    out = ""
    for seg in tok:
        out += seg[0]
    return out

def build_tokens(first, time, last):
    toks = []
    # Everything in `first` up to the last space is ordinary ink text; whatever
    # trails after that space is glued to the front of the time phrase.
    lead = ""
    if first != "":
        sp = first.rfind(" ")
        if sp < 0:
            lead = first
        else:
            for w in first[:sp].split(" "):
                if w != "":
                    toks.append([[w, False]])
            lead = first[sp + 1:]
    tail = ""
    rest = ""
    if last != "":
        sp = last.find(" ")
        if sp < 0:
            tail = last
        else:
            tail = last[:sp]
            rest = last[sp + 1:]
    core = []
    if lead != "":
        core.append([lead, False])
    core.append([time, True])
    if tail != "":
        core.append([tail, False])
    toks.append(core)
    for w in rest.split(" "):
        if w != "":
            toks.append([[w, False]])
    return toks

def wrap_tokens(c, toks, maxw, maxlines):
    """Greedy, left-aligned, ragged right -- which is how prose is set. Returns
    None if it needs more than maxlines."""
    lines, cur, curw = [], [], 0
    for t in toks:
        w = tok_w(c, t)
        if w > maxw and len(cur) == 0:
            return None
        if len(cur) == 0:
            cur, curw = [t], w
        elif curw + WORD_GAP + w <= maxw:
            cur.append(t)
            curw += WORD_GAP + w
        else:
            lines.append(cur)
            if len(lines) >= maxlines:
                return None
            cur, curw = [t], w
    if len(cur) > 0:
        lines.append(cur)
    return lines if len(lines) <= maxlines else None

def has_time(line):
    for t in line:
        for seg in t:
            if seg[1]:
                return True
    return False

# ---- the fit --------------------------------------------------------------
# A reader forgives a trailing ellipsis far more readily than a cold
# mid-sentence start, so the lead is only ever trimmed at a sentence boundary
# and all the mid-flow damage is taken at the tail, marked honestly.

def last_sentence(s):
    best = -1
    for mark in [". ", "! ", "? "]:
        i = s.rfind(mark)
        if i > best:
            best = i
    return s[best + 2:] if best >= 0 else s

def first_sentence(s):
    best = -1
    for mark in [".", "!", "?"]:
        i = s.find(mark)
        if i >= 0 and (best < 0 or i < best):
            best = i
    if best < 0:
        return s
    end = best + 1
    if end < len(s) and (s[end] == "\"" or s[end] == "'" or s[end] == ")"):
        end += 1
    return s[:end]

def fit_quote(c, q, maxw, maxlines):
    a, t, b = q["first"], q["time"], q["last"]
    for attempt in range(3):
        if attempt == 1:
            a = last_sentence(a)
        if attempt == 2:
            b = first_sentence(b)
        L = wrap_tokens(c, build_tokens(a, t, b), maxw, maxlines)
        if L != None:
            return L
    # Drop whole words off the tail until it fits, then say so with an
    # ellipsis. Words of two letters or fewer go first so it never ends on
    # "stood there a ...".
    words = b.split(" ")
    for _ in range(60):
        if len(words) == 0:
            break
        words = words[:len(words) - 1]
        if len(words) > 0 and len(words[len(words) - 1]) <= 2:
            continue
        L = wrap_tokens(c, build_tokens(a, t, " ".join(words) + "..."), maxw,
                        maxlines)
        if L != None:
            return L
    # Last resort: open cold on the amber time phrase. Striking, not broken.
    L = wrap_tokens(c, build_tokens("", t, ""), maxw, maxlines)
    return L if L != None else [[[[t, True]]]]

def attribution(c, q, maxw):
    """Title first. On a wall THE GREAT GATSBY identifies the source faster
    than a surname does, so the author is what goes when something must."""
    ti, au = q["title"], q["author"]
    if ti == "" and au == "":
        return ""
    cands = []
    if ti != "" and au != "":
        cands.append(ti + ", " + au)
        sur = ""
        for part in au.replace(" AND ", " & ").split("&"):
            w = part.strip().split(" ")
            if len(w) > 0 and w[len(w) - 1] != "":
                sur = w[len(w) - 1] if sur == "" else sur + " & " + w[len(w) - 1]
        if sur != "" and sur != au:
            cands.append(ti + ", " + sur)
    if ti != "":
        cands.append(ti)
    else:
        cands.append(au)
    for s in cands:
        if c.text_width(s, "4x5") <= maxw:
            return s
    return clip_words(c, cands[len(cands) - 1], "4x5", maxw)

# ---- page -----------------------------------------------------------------
# No tab chip. The accent's whole job here is to make the time phrase glow
# inside white prose, and a second amber block at the top-left would dilute the
# one piece of colour that means something. A chip reading BOOK would also
# caption a page of type, and this app is a page of type. The rail stays: it is
# quiet, it carries the family signature, and it brackets the composition
# against the colophon on the right.

TEXT_L = 6
MEASURE = 184
TOPS = {1: [9], 2: [5, 13], 3: [1, 9, 17]}

def draw_line(c, x, y, line):
    cx = x
    for i in range(len(line)):
        if i > 0:
            cx += SPACE_ADV
        for seg in line[i]:
            if seg[0] == "":
                continue
            cx = prose_draw(c, cx, y, seg[0], AMBER if seg[1] else INK)
    return cx

def line_w(c, line):
    w = 0
    for i in range(len(line)):
        if i > 0:
            w += WORD_GAP
        w += tok_w(c, line[i])
    return w

def book(c, ctx):
    c.fill("black")
    st = read_lit(ctx)
    if st["state"] != "ok" or st["q"] == None:
        rail(c, OFFLINE)
        message(c, "NO PASSAGE", "CANT REACH THE LITERATURE CLOCK DATA")
        return
    rail(c, AMBER)
    q = st["q"]

    lines = fit_quote(c, q, MEASURE, 3)
    tops = TOPS[len(lines)] if len(lines) in TOPS else [1, 9, 17]
    for i in range(len(lines)):
        if i >= len(tops):
            break
        # A single line set flush left on a 192px panel looks abandoned;
        # centred, the panel becomes one line of type, which is an epigraph.
        # Two or three lines stay left and ragged right, like prose.
        if len(lines) == 1:
            x = TEXT_L + (MEASURE - line_w(c, lines[i])) // 2
        else:
            x = TEXT_L
        draw_line(c, x, tops[i], lines[i])

    att = attribution(c, q, MEASURE)
    if att != "":
        c.text(att, 189, 26, font = "4x5", color = DIM, align = "right")
