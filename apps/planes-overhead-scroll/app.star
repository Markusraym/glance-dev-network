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

# ---- the aircraft ---------------------------------------------------------
# `track` arrives as a real bearing in degrees (318.09, not "NW"), and the old
# app threw that away by bucketing to eight compass points and drawing a 5x5
# blob.
#
# Three approaches were tried. Rotating a sprite by an arbitrary angle means
# resampling, and resampling a 15px silhouette shreds it -- the cardinals
# survive and every diagonal becomes a spiky mess. Deriving 16 bearings from
# three hand-drawn masters via the square's symmetries is pixel-exact, but
# still only gives 16 fixed angles and needs 48 sprites for three families.
#
# So the aircraft is not a sprite at all. It is drawn from three lines -- a
# fuselage along the heading, a wing bar across it, a tailplane -- rotated to
# the EXACT bearing. Bresenham is clean at every angle, so 318.09 degrees draws
# at 318.09 degrees, there is no sprite data in the file, and the shape is
# whatever the aircraft family needs it to be.

DEG = 3.141592653589793 / 180.0

# family -> [nose, tail, wing span, tail span, wing pos, tail pos, fuselage
#            thickness, wing thickness, engine pods]
SHAPES = {
    "jet":   [6.5, 6.0, 6.8, 3.2, 0.6, -4.6, 3, 2, 0],
    "light": [5.5, 5.5, 6.8, 3.0, 1.6, -4.4, 2, 2, 0],
    "heavy": [7.0, 6.5, 7.2, 3.8, 0.2, -5.2, 3, 2, 4],
    "rotor": [4.0, 4.5, 0.0, 2.6, 0.0, -4.0, 3, 2, 0],
}

def family_for(cat, typ):
    """ADS-B emitter category first, type code as a fallback. A7 is the only
    unambiguous rotorcraft signal in the feed; A5/A4 are the wide-bodies."""
    ca = str(cat).upper()
    if ca == "A7":
        return "rotor"
    if ca == "A5" or ca == "A4":
        return "heavy"
    if ca == "A1" or ca == "B1" or ca == "B4":
        return "light"
    t = str(typ).upper()
    if t.startswith("R") or t.startswith("EC") or t.startswith("B4") or t.startswith("S7"):
        return "rotor"
    if t.startswith("C1") or t.startswith("P2") or t.startswith("PA") or t.startswith("SR"):
        return "light"
    if t.startswith("B74") or t.startswith("A38") or t.startswith("B77") or t.startswith("A35"):
        return "heavy"
    return "jet"

def _thick_line(c, x0, y0, x1, y1, t, col):
    """A line with body. Offsetting perpendicular keeps the thickness even at
    every angle; offsetting in x or y would fatten diagonals and starve the
    cardinals."""
    c.line(int(x0), int(y0), int(x1), int(y1), col)
    if t <= 1:
        return
    dx, dy = x1 - x0, y1 - y0
    ln = math.sqrt(dx * dx + dy * dy)
    if ln < 0.001:
        return
    px, py = -dy / ln, dx / ln
    k = 1
    for _ in range(4):
        if k > (t - 1) // 2:
            break
        for s in [-1, 1]:
            ox, oy = px * k * s, py * k * s
            c.line(int(x0 + ox), int(y0 + oy), int(x1 + ox), int(y1 + oy), col)
        k += 1

def draw_aircraft(c, cx, cy, bearing, fam, col, scale = 1):
    """Top-down aircraft centred on (cx, cy) pointing at `bearing` degrees,
    0 = north, clockwise. `bearing` may be None for something on the ground
    with no heading -- the caller decides what to draw instead; pointing north
    and inventing a heading would be a lie."""
    s = SHAPES[fam] if fam in SHAPES else SHAPES["jet"]
    a = bearing * DEG
    fx, fy = math.sin(a), -math.cos(a)
    px, py = -fy, fx
    nose, tail = s[0] * scale, s[1] * scale
    span, tspan = s[2] * scale, s[3] * scale
    wat, tat = s[4] * scale, s[5] * scale

    _thick_line(c, cx - fx * tail, cy - fy * tail,
                cx + fx * nose, cy + fy * nose, s[6], col)
    if span > 0:
        wx, wy = cx + fx * wat, cy + fy * wat
        _thick_line(c, wx - px * span, wy - py * span,
                    wx + px * span, wy + py * span, s[7], col)
    tx, ty = cx + fx * tat, cy + fy * tat
    _thick_line(c, tx - px * tspan, ty - py * tspan,
                tx + px * tspan, ty + py * tspan, s[7], col)
    if s[8] == 4:
        wx, wy = cx + fx * wat, cy + fy * wat
        for off in [0.45, 0.8]:
            for sg in [-1, 1]:
                ex = wx + px * span * off * sg + fx * 0.9
                ey = wy + py * span * off * sg + fy * 0.9
                c.pixel(int(ex), int(ey), col)

def draw_rotor(c, cx, cy, bearing, col, blade_col):
    """A rotorcraft from above. Blades are drawn as two crossed lines rather
    than a ring -- a ring at this size reads as a no-entry sign. The blades do
    not rotate with heading (they spin, so any angle is honest), but the body
    and tail boom do, which is what actually tells you where it is going."""
    x, y = int(cx), int(cy)
    c.line(x - 6, y - 6, x + 6, y + 6, blade_col)
    c.line(x - 6, y + 6, x + 6, y - 6, blade_col)
    b = (bearing if bearing != None else 0.0) * DEG
    fx, fy = math.sin(b), -math.cos(b)
    c.fill_circle(x, y, 2, col)
    tx, ty = x - fx * 7, y - fy * 7
    c.line(x, y, int(tx), int(ty), col)
    px, py = -fy, fx
    c.line(int(tx - px * 2), int(ty - py * 2), int(tx + px * 2), int(ty + py * 2), col)

# ---- data -----------------------------------------------------------------
ADSB = "https://api.adsb.lol/v2/point/"
ADSBDB = "https://api.adsbdb.com/v0/callsign/"
ZIP = "https://api.zippopotam.us/us/"

# Altitude bands. The colour says how high without reading a number, and the
# band is also where the aircraft sits vertically on the sky page.
BANDS = [
    [1500, "#FF4FCB", "PATTERN"],
    [5000, "#FF6A00", "LOW"],
    [12000, "#FFB300", "CLIMB"],
    [24000, "#7FE9FF", "MID"],
    [99000, "#78DCFF", "HIGH"],
]

def band_of(alt):
    for b in BANDS:
        if alt <= b[0]:
            return b
    return BANDS[len(BANDS) - 1]

def kt_to_mph(kt):
    return kt * 1151 // 1000

def read_sky(ctx):
    zipc = str(ctx.inputs.get("zip", "")).strip()
    radius = num(ctx.inputs.get("radius", "20"), 20)
    if radius < 5:
        radius = 5
    if radius > 250:
        radius = 250
    st = {"state": "ok", "planes": [], "zip": zipc, "radius": radius,
          "place": "", "now": ctx.now.unix // 60}
    if zipc == "":
        st["state"] = "setup"
        return st

    z = http.get(ZIP + zipc, ttl_seconds = 86400)
    if z["status_code"] != 200 or z["json"] == None:
        st["state"] = "badzip"
        return st
    places = get(z["json"], "places", [])
    if type(places) != "list" or len(places) == 0:
        st["state"] = "badzip"
        return st
    p0 = places[0]
    lat = str(get(p0, "latitude", ""))
    lon = str(get(p0, "longitude", ""))
    st["place"] = str(get(p0, "place name", "")).upper()

    r = http.get(ADSB + lat + "/" + lon + "/" + str(radius), ttl_seconds = 60)
    if r["status_code"] != 200 or r["json"] == None:
        st["state"] = "offline"
        return st
    for a in get(r["json"], "ac", []):
        if type(a) != "dict":
            continue
        alt_raw = a.get("alt_baro", None)
        # alt_baro is feet OR the literal string "ground". Treating that string
        # as a number is how an app ends up drawing a taxiing jet at 0 feet in
        # the middle of the sky.
        on_ground = str(alt_raw).lower() == "ground"
        alt = 0 if on_ground else num(alt_raw, -1)
        if alt < 0 and not on_ground:
            continue
        track = a.get("track", None)
        rate = a.get("baro_rate", a.get("geom_rate", None))
        st["planes"].append({
            "reg": str(get(a, "r", "")).strip().upper(),
            "call": str(get(a, "flight", "")).strip().upper(),
            "type": str(get(a, "t", "")).strip().upper(),
            "cat": str(get(a, "category", "")).strip().upper(),
            "alt": alt, "ground": on_ground,
            "track": track,
            "rate": intpart(rate, 0) if rate != None else 0,
            "gs": intpart(get(a, "gs", 0), 0),
            "dst": dec(str(get(a, "dst", "0")), 1) or 0,
            "squawk": str(get(a, "squawk", "")).strip(),
            "seen": num(get(a, "seen", 0), 0),
        })
    if len(st["planes"]) == 0:
        st["state"] = "empty"
        return st
    st["planes"] = sorted(st["planes"], key = interest)
    return st

def emergency(p):
    """7500 hijack, 7600 radio failure, 7700 general emergency. These are the
    only three squawks worth interrupting a panel for."""
    return p["squawk"] in ["7500", "7600", "7700"]

def interest(p):
    """Lower sorts first. An emergency squawk outranks everything; after that
    the interesting aircraft is the close, low one -- something at 38,000ft
    passing overhead is not what a person looks up at."""
    if emergency(p):
        return -1000000
    if p["ground"]:
        return 900000 + p["dst"]
    return p["alt"] // 100 + p["dst"] * 3

def route_for(call):
    """Origin and destination for a callsign, or None. adsbdb answers for
    airline flights and 404s for private ones, which is most of the sky."""
    if call == "":
        return None
    r = http.get(ADSBDB + call, ttl_seconds = 3600)
    if r["status_code"] != 200 or r["json"] == None:
        return None
    fr = dig(r["json"], ["response", "flightroute"], None)
    if fr == None:
        return None
    o = dig(fr, ["origin", "iata_code"], "")
    d = dig(fr, ["destination", "iata_code"], "")
    if o == "" or d == "":
        return None
    return [str(o).upper(), str(d).upper(),
            str(dig(fr, ["airline", "name"], "")).upper()]

def rate_word(r):
    if r > 300:
        return ["CLIMB", "#00E36B"]
    if r < -300:
        return ["DESCEND", "#FFB300"]
    return ["LEVEL", "gray"]

def alt_text(p):
    if p["ground"]:
        return "GROUND"
    if p["alt"] >= 10000:
        return str(p["alt"] // 1000) + "K FT"
    return fmt.commas(p["alt"]) + " FT"

# ---- pages ----------------------------------------------------------------
# The one idea: the aircraft is drawn at its REAL heading, big, and the panel
# is read as sky. On OVERHEAD the aircraft sits at the height its altitude band
# puts it; on SKY every aircraft in range is placed by distance and drawn
# pointing where it is actually going. Nothing here is a list with an icon
# beside it.

SKY_TOP = 3
SKY_BOT = 29

def alt_y(p):
    """Vertical position for an altitude: high things ride high on the panel."""
    if p["ground"]:
        return SKY_BOT
    a = p["alt"]
    if a > 40000:
        a = 40000
    return SKY_BOT - a * (SKY_BOT - SKY_TOP) // 40000

def plane_glyph(c, cx, cy, p, col, scale = 1):
    fam = family_for(p["cat"], p["type"])
    if fam == "rotor":
        draw_rotor(c, cx, cy, p["track"], col, color.dim(col, 55))
    elif p["track"] == None:
        # No heading: something parked. Drawing it pointing north would invent
        # a fact, so it gets a plan view with no direction instead.
        draw_aircraft(c, cx, cy, 0.0, fam, color.dim(col, 55), scale)
    else:
        draw_aircraft(c, cx, cy, p["track"], fam, col, scale)

def fail(c, st):
    if st["state"] == "setup":
        rail(c, STRUCT)
        message(c, "ADD YOUR ZIP CODE", "US ZIP - SETS WHERE TO LOOK UP")
        return True
    if st["state"] == "badzip":
        rail(c, STRUCT)
        message(c, "ZIP NOT FOUND", "CHECK THE ZIP CODE")
        return True
    if st["state"] == "offline":
        rail(c, OFFLINE)
        message(c, "NO ADS-B FEED", "CANT REACH THE RECEIVER NETWORK")
        return True
    if st["state"] == "empty":
        rail(c, STRUCT)
        message(c, "EMPTY SKY", "NOTHING IN RANGE RIGHT NOW")
        return True
    return False

# ------------------------------------------------------- page 1: overhead
def overhead(c, ctx):
    c.fill("black")
    st = read_sky(ctx)
    if fail(c, st):
        tab(c, "SKY", "#78DCFF")
        return
    p = st["planes"][0]
    band = band_of(p["alt"])
    col = "#FF2D2D" if emergency(p) else band[1]
    rail(c, col)

    tab(c, "SKY", col)
    head = p["call"] if p["call"] != "" else p["reg"]
    c.text(clip(c, head, "4x5", 70), 30, 2, font = "4x5", color = "white")
    c.text(str(len(st["planes"])) + " IN RANGE", 190, 2, font = "4x5",
           color = "gray", align = "right")

    # The aircraft, large, at its true bearing.
    plane_glyph(c, 22, 18, p, col, 1)

    if emergency(p):
        c.text("SQUAWK " + p["squawk"], 44, 8, font = "5x7", color = "#FF2D2D")
        c.text("EMERGENCY", 44, 18, font = "6x8", color = "#FF2D2D")
        return

    # Type and registration, then the numbers that matter.
    tline = p["type"]
    if p["reg"] != "" and p["reg"] != head:
        tline = tline + "  " + p["reg"]
    c.text(clip(c, tline, "4x5", 60), 44, 9, font = "4x5", color = "gray")

    af = fit(c, alt_text(p), ["8x12", "6x8"], 62)
    c.text(af[1], 44, 16, font = af[0], color = col)

    rw = rate_word(p["rate"])
    if not p["ground"]:
        c.trend_arrow(44, 27, 1 if p["rate"] > 300 else (-1 if p["rate"] < -300 else 0),
                      color = rw[1])
        c.text(rw[0], 52, 27, font = "4x5", color = rw[1])

    c.vline(112, 8, 21, STRUCT)
    r = route_for(p["call"])
    if r != None:
        c.text(r[0], 118, 9, font = "6x8", color = "white")
        c.text(">", 118 + c.text_width(r[0], "6x8") + 3, 10, font = "5x7",
               color = "gray")
        c.text(r[1], 190, 9, font = "6x8", color = "white", align = "right")
        if r[2] != "":
            c.text(clip(c, r[2], "4x5", 72), 118, 20, font = "4x5", color = "gray")
    else:
        c.text("NO ROUTE FILED", 118, 10, font = "4x5", color = "midgray")
    c.text(str(kt_to_mph(p["gs"])) + " MPH", 118, 27, font = "4x5", color = "gray")
    if p["dst"] > 0:
        c.text(str(p["dst"] // 10) + "." + str(p["dst"] % 10) + " MI", 190, 27,
               font = "4x5", color = "gray", align = "right")

# ------------------------------------------------------------ page 2: sky
def sky(c, ctx):
    c.fill("black")
    st = read_sky(ctx)
    if fail(c, st):
        tab(c, "TRAFFIC", "#78DCFF")
        return
    rail(c, band_of(st["planes"][0]["alt"])[1])
    tab(c, "TRAFFIC", "#78DCFF")
    c.text(clip(c, st["place"], "4x5", 60), 46, 2, font = "4x5", color = "gray")
    c.text(str(len(st["planes"])) + " WITHIN " + str(st["radius"]) + "MI", 190, 2,
           font = "4x5", color = "gray", align = "right")

    # Ground line and the horizon, so height on the panel reads as height.
    c.hline(2, 31, 188, "#1A1A22")
    for x in range(2, 190, 6):
        c.pixel(x, SKY_TOP - 1, "#1A1A22")

    # Five, not seven. A callsign is up to 29px at 4x5 and seven columns leave
    # 22px each, so the labels ran into one another and read as one long word.
    shown = st["planes"][:5]
    n = len(shown)
    step = 176 // n if n > 0 else 176
    for i in range(n):
        p = shown[i]
        cx = 16 + i * step + step // 2 - 8
        cy = alt_y(p)
        # Labels share one baseline so they line up instead of stepping with
        # the aircraft; the aircraft are clamped to leave that row clear.
        if cy < 9:
            cy = 9
        if cy > 20:
            cy = 20
        col = "#FF2D2D" if emergency(p) else band_of(p["alt"])[1]
        plane_glyph(c, cx, cy, p, col, 1)
        lab = p["call"] if p["call"] != "" else p["reg"]
        # The callsign carries the altitude band as its colour, rather than a
        # second row of digits underneath: there is only one label row of
        # headroom under the aircraft, and the band palette already says how
        # high without being read.
        c.text(clip(c, lab, "4x5", step - 3), cx, 26, font = "4x5",
               color = col, align = "center")
