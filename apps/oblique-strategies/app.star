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

# ---- oblique strategies ---------------------------------------------------
# Brian Eno and Peter Schmidt's deck, 1975. One card a day.
#
# The real object is a plain white card, black type, in a black box, and its
# power is that it refuses to explain itself. So this app has no page tab, no
# accent rail, no date, no card number and no countdown -- all of which would
# turn an oracle into a widget. What it has instead is four registration ticks
# in the corners, the way crop marks on a proof say "a card was printed here"
# without ever touching the words.
#
# It is also the only app on the network set in lowercase. Everything else
# shouts because the fonts make it; 5x5 can murmur, and the deck's whole
# register is an instruction slipped under a door.

TICK = "#4A5468"
CARD = "#F4F7FF"

DECK = [
    "Abandon normal instruments.",
    "Accept advice.",
    "Accretion.",
    "A line has two sides.",
    "Allow an easement.",
    "Are there sections? Consider transitions.",
    "Ask people to work against their better judgement.",
    "Ask your body.",
    "Balance the consistency principle with the inconsistency principle.",
    "Be dirty.",
    "Breathe more deeply.",
    "Bridges - build - burn.",
    "Cascades.",
    "Change instrument roles.",
    "Change nothing and continue with immaculate consistency.",
    "Children's voices - speaking - singing.",
    "Cluster analysis.",
    "Consider different fading systems.",
    "Consult other sources - promising - unpromising.",
    "Convert a melodic element into a rhythmic element.",
    "Courage!",
    "Cut a vital connection.",
    "Decorate, decorate.",
    "Define an area as safe and use it as an anchor.",
    "Destroy nothing. Destroy the most important thing.",
    "Discard an axiom.",
    "Disciplined self-indulgence.",
    "Disconnect from desire.",
    "Discover the recipes you are using and abandon them.",
    "Distorting time.",
    "Do nothing for as long as possible.",
    "Do something boring.",
    "Do the washing up.",
    "Do the words need changing?",
    "Do we need holes?",
    "Emphasize differences.",
    "Emphasize repetitions.",
    "Emphasize the flaws.",
    "Faced with a choice, do both.",
    "Feed the recording back out of the medium.",
    "Fill every beat with something.",
    "Get your neck massaged.",
    "Give the game away.",
    "Give way to your worst impulse.",
    "Go slowly all the way round the outside.",
    "Honour thy error as a hidden intention.",
    "How would you have done it?",
    "Humanize something free of error.",
    "Idiot glee.",
    "Infinitesimal gradations.",
    "Intentions - credibility of - nobility of - humility of.",
    "In total darkness, or in a very large room, very quietly.",
    "Is it finished?",
    "Is there something missing?",
    "Just carry on.",
    "Left channel, right channel, centre channel.",
    "Listen to the quiet voice.",
    "Look at a very small object. Look at its centre.",
    "Look at the order in which you do things.",
    "Look closely at the most embarrassing details and amplify them.",
    "Lowest common denominator.",
    "Make a blank valuable by putting it in an exquisite frame.",
    "Make an exhaustive list of everything you might do.",
    "Make a sudden, destructive, unpredictable action. Incorporate.",
    "Mechanicalize something idiosyncratic.",
    "Mute and continue.",
    "Not building a wall but making a brick.",
    "Once the search is in progress, something will be found.",
    "Only a part, not the whole.",
    "Only one element of each kind.",
    "Overtly resist change.",
    "Put in earplugs.",
    "Question the heroic approach.",
    "Remember those quiet evenings.",
    "Remove ambiguities and convert to specifics.",
    "Remove specifics and convert to ambiguities.",
    "Repetition is a form of change.",
    "Reverse.",
    "Short circuit.",
    "Shut the door and listen from outside.",
    "Simple subtraction.",
    "Spectrum analysis.",
    "State the problem in words as clearly as possible.",
    "Steal a solution.",
    "Take a break.",
    "Take away the elements in order of apparent non-importance.",
    "Tape your mouth.",
    "The inconsistency principle.",
    "The most important thing is the thing most easily forgotten.",
    "The tape is now the music.",
    "Think of the radio.",
    "Tidy up.",
    "Towards the insignificant.",
    "Trust in the you of now.",
    "Turn it upside down.",
    "Twist the spine.",
    "Use an old idea.",
    "Use an unacceptable colour.",
    "Use fewer notes.",
    "Use filters.",
    "Use something nearby as a model.",
    "Use your own ideas.",
    "Voice your suspicions.",
    "Water.",
    "What are you really thinking about just now?",
    "What is the reality of the situation?",
    "What mistakes did you make last time?",
    "What would your closest friend do?",
    "What wouldn't you do?",
    "When is it for?",
    "Which parts can be grouped?",
    "Work at a different speed.",
    "Would anybody want it?",
    "You are an engineer.",
    "You can only make one dot at a time.",
    "Your mistake was a hidden intention.",
    "Gardening, not architecture.",
    "Don't be frightened of cliches.",
    "Don't be frightened to display your talents.",
    "Don't stress one thing more than another.",
    "It is quite possible (after all).",
    "Go to an extreme, move back to a more comfortable place.",
]

# Line tops by line count. The pitch is 8 because a descender is 7 rows tall
# and would otherwise land on the next line's capitals; odd counts put their
# middle line on 13, which is the panel's optical centre.
TOPS = {1: [13], 2: [9, 17], 3: [5, 13, 21]}

def card_for(ctx):
    """One card a day, and never the same card two days running.

    The index is a pure function of the local date, so a power cut, a refresh
    or a re-render never reshuffles the day's card -- it is drawn once, at
    midnight, by arithmetic."""
    n = len(DECK)
    z = days_from_civil(ctx.now.year, ctx.now.month, ctx.now.day)
    # Knuth's multiplicative hash, so consecutive days are decorrelated rather
    # than walking through the deck in order.
    i = (z * 2654435761) % 4294967296 % n
    j = ((z - 1) * 2654435761) % 4294967296 % n
    if i == j:
        i = (i + 1) % n
    return DECK[i]

def ticks(c):
    for p in [[1, 1, 1, 1], [190, 1, -1, 1], [1, 30, 1, -1], [190, 30, -1, -1]]:
        x, y, dx, dy = p[0], p[1], p[2], p[3]
        for k in range(4):
            c.pixel(x + dx * k, y, TICK)
            c.pixel(x, y + dy * k, TICK)

def strategy(c, ctx):
    c.fill("black")
    ticks(c)
    text = normalise(card_for(ctx))
    words = text.split(" ")
    lines = None
    for n in [1, 2, 3]:
        lines = balance(c, words, 176, n)
        if lines != None:
            break
    if lines == None:
        # Nothing in the deck needs four lines, but a card added later might.
        lines = balance(c, words, 176, 4)
        if lines == None:
            lines = [clip(c, text, "5x5", 176)]
    tops = TOPS[len(lines)] if len(lines) in TOPS else [3, 10, 17, 24]
    for i in range(len(lines)):
        if i >= len(tops):
            break
        prose_draw(c, hang_x(c, lines[i], 192), tops[i], lines[i], CARD)
