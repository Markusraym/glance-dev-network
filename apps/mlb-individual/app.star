# MLB Scores — GDN port of the Pixlet app.
#
# Data logic follows the original; the render tree is rewritten as c.* calls.
#
# Layout (64x32):
#   left  0-31   two team-coloured quadrants: ABBR + score
#   right 32-63  base diamond, inning arrow, and the B/S/O count
#                (or FINAL / start time)

SCOREBOARD = "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard"

FONT = "4x5"
TINY = "3x4"

PANEL_BG = "#111111"
BALL = "#00CC44"
STRIKE = "#FFCC00"
OUT = "#FF3333"
OFF = "#333333"
ARROW = "#FFCC00"
BASE_ON = "#FFCC00"
BASE_OFF = "#444444"

TEAM_COLORS = {
    "ARI": ("#A71930", "#ffffff"),
    "ATH": ("#003831", "#EFB21E"),
    "ATL": ("#13274F", "#CE1141"),
    "BAL": ("#000000", "#DF4601"),
    "BOS": ("#BD3039", "#0C2340"),
    "CHC": ("#0E3386", "#CC3433"),
    "CWS": ("#27251F", "#ffffff"),
    "CHW": ("#27251F", "#ffffff"),
    "CIN": ("#C6011F", "#ffffff"),
    "CLE": ("#00385D", "#E31937"),
    "COL": ("#33006F", "#C4CED4"),
    "DET": ("#0C2340", "#FA4616"),
    "HOU": ("#002D62", "#EB6E1F"),
    "KC": ("#004687", "#ffffff"),
    "LAA": ("#BA0021", "#ffffff"),
    "LAD": ("#005A9C", "#ffffff"),
    "MIA": ("#00A3E0", "#ffffff"),
    "MIL": ("#12284B", "#FFC52F"),
    "MIN": ("#002B5C", "#D31145"),
    "NYM": ("#002D72", "#FF5910"),
    "NYY": ("#0C2340", "#C4CED4"),
    "OAK": ("#003831", "#EFB21E"),
    "PHI": ("#002D72", "#E81828"),
    "PIT": ("#000000", "#FDB827"),
    "SD": ("#2F241D", "#FFC425"),
    "SF": ("#27251F", "#FD5A1E"),
    "SEA": ("#0C2C56", "#005C5C"),
    "STL": ("#C41E3A", "#ffffff"),
    "TB": ("#092C5C", "#ffffff"),
    "TEX": ("#003278", "#C0111F"),
    "TOR": ("#134A8E", "#ffffff"),
    "WSH": ("#AB0003", "#ffffff"),
}

def team_color(abbr, idx):
    return TEAM_COLORS.get(abbr, ("#333333", "#cccccc"))[idx]

# ---------------------------------------------------------------- data

def fetch(ttl):
    resp = http.get(SCOREBOARD, ttl_seconds = ttl)
    if resp["status_code"] != 200 or resp["json"] == None:
        return None
    return resp["json"]

def digits_only(s):
    out = ""
    for ch in s.elems():
        if ch >= "0" and ch <= "9":
            out += ch
    return out

def parse_offset(raw):
    """Hours from UTC out of the free-text field, or -4 when it isn't a number.

    The field is free text, so "EST", "-4:00" and "FOUR" all reach here, and
    int() raises on every one of them -- which takes the whole render down and
    leaves the panel blank because someone typed a timezone name. Read the
    digits out instead and fall back to Eastern."""
    t = str(raw).strip()
    neg = t.startswith("-")
    if neg or t.startswith("+"):
        t = t[1:]
    # Input values ride a colon-separated render descriptor, so "-4:30" already
    # arrives as "-4"; split anyway for the local preview, where it does not.
    t = t.split(":")[0].split(".")[0].strip()
    d = digits_only(t)
    if d == "":
        return -4
    h = int(d)
    if h > 14:
        h = 14
    return -h if neg else h

def local_start(raw, offset):
    """'2026-08-16T19:10Z' -> '7:10P' at the user's offset."""
    parts = raw.split("T")
    if len(parts) != 2:
        return ""
    hm = parts[1].replace("Z", "").split(":")
    if len(hm) < 2:
        return ""
    hh = digits_only(hm[0])
    if hh == "":
        return ""
    hour = int(hh) + offset
    if hour < 0:
        hour += 24
    if hour >= 24:
        hour -= 24
    ampm = "P" if hour >= 12 else "A"
    h12 = hour % 12
    if h12 == 0:
        h12 = 12
    return str(h12) + ":" + hm[1] + ampm

def jersey(slot):
    """ESPN nests the number at situation.<role>.athlete.jersey. It is absent
    between innings and on some feeds, so fall back to a dash."""
    n = slot.get("athlete", {}).get("jersey", "")
    if n == None or n == "":
        return "-"
    return str(n)

def find_game(data, abbr):
    for event in data.get("events", []):
        comps = event.get("competitions", [])
        if len(comps) == 0:
            continue
        comp = comps[0]

        home, away, found = None, None, False
        for cr in comp.get("competitors", []):
            if cr.get("homeAway") == "home":
                home = cr
            else:
                away = cr
            if cr.get("team", {}).get("abbreviation", "") == abbr:
                found = True
        if not found or home == None or away == None:
            continue

        status = event.get("status", {})
        stype = status.get("type", {})
        state = stype.get("state", "")
        detail = stype.get("shortDetail", "")
        low = detail.lower()

        delayed = False
        for word in ["delay", "suspend", "postpone"]:
            if word in low:
                delayed = True

        sit = comp.get("situation", {})

        # Inning number: prefer the digits in shortDetail ("Top 3rd" -> 3),
        # fall back to status.period.
        inning = digits_only(str(status.get("period", 1)).split(".")[0])
        for word in detail.split(" "):
            d = digits_only(word)
            if d != "":
                inning = d
                break

        top = True
        for word in ["bot", "bottom", "end"]:
            if word in low:
                top = False

        return {
            "state": state,
            "delayed": delayed,
            "home": home.get("team", {}).get("abbreviation", "???"),
            "away": away.get("team", {}).get("abbreviation", "???"),
            "home_score": str(home.get("score", "0")),
            "away_score": str(away.get("score", "0")),
            "inning": inning,
            "top": top,
            "balls": int(sit.get("balls", 0)),
            "strikes": int(sit.get("strikes", 0)),
            "outs": int(sit.get("outs", 0)),
            "pitcher": jersey(sit.get("pitcher", {})),
            "batter": jersey(sit.get("batter", {})),
            "first": sit.get("onFirst", False) == True,
            "second": sit.get("onSecond", False) == True,
            "third": sit.get("onThird", False) == True,
            "date": event.get("date", ""),
        }
    return None

# ---------------------------------------------------------------- drawing

BIG = "5x7"

# (font, y offset) pairs, largest first. The offsets bottom-align every option
# on the same baseline as 5x7, so a shrunken score still sits level with the
# abbreviation instead of floating.
SCORE_FONTS = [(BIG, 4), (FONT, 6), (TINY, 7)]

SCORE_RIGHT = 29
ABBR_X = 2
GAP = 2

def fit_score(c, abbr, score):
    """Pick the largest font whose score clears the abbreviation by GAP px.
    At 5x7 a 3-letter abbr is 17px and a 2-digit score 11px, which collide in
    a 32px band — so double-digit scores shrink, single digits do not."""
    avail = SCORE_RIGHT - (ABBR_X + c.text_width(abbr, font = BIG) + GAP) + 1
    for font, dy in SCORE_FONTS:
        if c.text_width(score, font = font) <= avail:
            return (font, dy)
    return SCORE_FONTS[len(SCORE_FONTS) - 1]

def quadrant(c, y, abbr, score, bg, fg):
    """32x16 block: team colour behind the abbreviation and score. 5x7 matches
    the reference metrics — glyphs 5 wide on rows 5-10 of each band."""
    c.rect(0, y, 31, y + 15, fill = bg)
    c.text(abbr, ABBR_X, y + 4, font = BIG, color = fg)

    font, dy = fit_score(c, abbr, score)
    c.text(score, SCORE_RIGHT, y + dy, font = font, color = fg, align = "right")

def base(c, cx, cy, occupied):
    """11x11 diamond centred on (cx, cy). Outline when empty, solid when a
    runner is on. Radius 5, so rows run cy-5 .. cy+5."""
    col = BASE_ON if occupied else BASE_OFF
    for dy in range(-5, 6):
        half = 5 - (dy if dy >= 0 else -dy)
        if occupied:
            c.line(cx - half, cy + dy, cx + half, cy + dy, col)
        else:
            c.line(cx - half, cy + dy, cx - half, cy + dy, col)
            if half > 0:
                c.line(cx + half, cy + dy, cx + half, cy + dy, col)

def diamond(c, x0, first, second, third):
    """2nd at top centre, 3rd lower-left, 1st lower-right — the geometry from
    the reference: centres at local x 16 / 8 / 24, y 5 / 12 / 12."""
    base(c, x0 + 16, 5, second)
    base(c, x0 + 8, 12, third)
    base(c, x0 + 24, 12, first)

def count_squares(c, x0, y, balls, strikes, outs):
    """3x3 blocks: three balls, two strikes, two outs. 1px inside a group,
    2px between groups — local x 3,7,11 | 16,20 | 25,29."""
    groups = [(2, 3, balls, BALL), (15, 2, strikes, STRIKE), (24, 2, outs, OUT)]
    for gx, count, value, on_color in groups:
        for i in range(count):
            x = x0 + gx + i * 4
            col = on_color if i < value else OFF
            c.rect(x, y, x + 2, y + 2, fill = col)

def draw_arrow(c, cx, y, up, color):
    """Solid 7x4 triangle centred on cx. A stem or a thin caret turns to mush
    at this size — an unbroken wedge is the only shape that reads instantly.
    The bitmap fonts have no ^ or v glyph to fall back on."""
    for i in range(4):
        half = i if up else 3 - i
        c.line(cx - half, y + i, cx + half, y + i, color)

def jersey_row(c, x0, y, pitcher, batter):
    """P<num> left, B<num> right-aligned. The reference shows "P:32 B:7", but
    two 2-digit numbers plus colons overflow 32px at 4x5, so the colons go."""
    c.text("P", x0 + 1, y, font = FONT, color = ARROW)
    c.text(pitcher, x0 + 6, y, font = FONT, color = "white")

    bw = 5 + c.text_width(batter, font = FONT)
    bx = x0 + 31 - bw
    c.text("B", bx, y, font = FONT, color = ARROW)
    c.text(batter, bx + 5, y, font = FONT, color = "white")

def right_panel(c, g, show_players):
    x0 = 32
    c.rect(x0, 0, c.width - 1, 31, fill = PANEL_BG)
    mid = x0 + 16

    if g["state"] == "post":
        c.text("FINAL", mid, 13, font = FONT, color = "white", align = "center")
        return

    if g["state"] == "pre":
        c.text(local_start(g["date"], g["offset"]), mid, 9,
               font = FONT, color = "white", align = "center")
        if g["delayed"]:
            c.text("DLY", mid, 17, font = FONT, color = ARROW, align = "center")
        return

    if g["delayed"]:
        c.text("DELAY", mid, 13, font = FONT, color = ARROW, align = "center")
        return

    diamond(c, x0, g["first"], g["second"], g["third"])

    # Inning: caret then number, sitting under the diamond.
    draw_arrow(c, x0 + 11, 20, g["top"], ARROW)
    c.text(g["inning"], x0 + 18, 20, font = FONT, color = "white")

    if show_players:
        jersey_row(c, x0, 26, g["pitcher"], g["batter"])
    else:
        count_squares(c, x0, 29, g["balls"], g["strikes"], g["outs"])

def no_game(c, abbr):
    c.fill("black")
    bg = team_color(abbr, 0)
    fg = team_color(abbr, 1)
    c.rect(0, 0, c.width - 1, 31, fill = bg)
    c.text(abbr, c.width // 2, 9, font = FONT, color = fg, align = "center")
    c.text("NO GAME", c.width // 2, 17, font = TINY, color = fg, align = "center")

# ---------------------------------------------------------------- page

def draw(c, ctx, show_players):
    c.fill("black")

    abbr = ctx.inputs.get("team", "NYY").strip().upper()
    offset = parse_offset(ctx.inputs.get("utcoffset", "-4"))

    data = fetch(60)
    if data == None:
        c.text("NO DATA", c.width // 2, 13, font = FONT, color = "red", align = "center")
        return

    g = find_game(data, abbr)
    if g == None:
        no_game(c, abbr)
        return
    g["offset"] = offset

    quadrant(c, 0, g["away"], g["away_score"],
             team_color(g["away"], 0), team_color(g["away"], 1))
    quadrant(c, 16, g["home"], g["home_score"],
             team_color(g["home"], 0), team_color(g["home"], 1))
    right_panel(c, g, show_players)

def count(c, ctx):
    draw(c, ctx, False)

def players(c, ctx):
    draw(c, ctx, True)