# HS Football Schedule -- the next few football games for one high school,
# read from a MaxPreps schedule scraper hosted on parse.bot.
#
# parse.bot turns a scraped site into a per-scraper REST endpoint:
#   https://api.parse.bot/scraper/<scraper id>/<endpoint name>
# authenticated with an X-API-Key header. The GDN runtime only offers
# http.get, so the school is passed as a query-string parameter -- parse.bot
# accepts GET + query string as well as POST + JSON body.
#
# Field names are read through _pick() rather than by exact key, because
# parse.bot names a scraper's output fields after the plain-English task it
# was built from: the same MaxPreps schedule can come back as "opponent" or
# "opponent_name", "home_away" or "site". Each _pick() call lists the aliases
# it accepts, and adding one more alias is how you adapt this app to a
# scraper whose fields are spelled differently.
#
# No logos: the panel is 32px tall and school mascot art does not survive the
# downscale, so this uses AWAY/HOME tags and the school names instead.

# The user's own forked copy of the MaxPreps API. The shared marketplace
# scraper (e0a033cc-...) had get_team_schedule failing 35 of 39 calls; parse.bot
# staged the fix into this fork, so this is the one to call.
SCRAPER_ID = "92667510-f172-4be0-b994-93762b390a6b"

# Two endpoints on the MaxPreps API, both confirmed against the live service:
#
#   search_schools?query=NAPLES        -> schools[] with name/city/state/path
#   get_team_schedule?path=/fl/naples/naples-golden-eagles/football/
#                                      -> {team:{...}, contests:[...]}
#
# The path MUST carry the sport suffix. The bare school path from
# search_schools ("/fl/naples/naples-golden-eagles/") is rejected; append
# "football/", and optionally a season ("football/26-27/schedule/") to pin
# the year, since the bare sport path serves whichever season MaxPreps has
# marked current.
#
# The app only calls the second one. get_team_schedule wants a MaxPreps team
# path rather than a school name, and resolving a name at render time is not
# an option: search_schools takes 4.2-4.8s against a 4s REQUEST_TIMEOUT in
# gdn/starhost/http_client.py, so it times out every time. The path is looked
# up once when the app is configured and pasted in, which also saves the 2
# credits per call that the search would burn on every refresh.
SCHEDULE_ENDPOINT = "get_team_schedule"

BASE = "https://api.parse.bot/scraper/"

# ---------------------------------------------------------------- palette
BG = "#05070D"
RAIL = "#FFB300"        # left accent bar
ME = "#FFC24A"          # the school you follow
OPP = "#DCE3F0"         # the other school
TAG_ON = "#FFB300"      # AWAY/HOME tag on your school's row
TAG_OFF = "#5D6785"
DIV = "#243149"
DATE_C = "#7FD1FF"
TIME_C = "#8A93AD"

MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

# Sample schedule behind the DEMO school, so the app (and the catalog
# previews) show real-looking cards without a key. Shaped like the scraper's
# own rows so it exercises the same parsing path as live data.
DEMO_SCHOOL = "CENTRAL"

# Shaped exactly like get_team_schedule's contests[]: the subject school on
# BOTH sides under home_team, the venue carried by is_home, the kickoff
# folded into the ISO date, and one duplicated row -- the live feed repeats
# contests, so the demo repeats one too and the dedupe gets exercised here
# rather than first meeting it on a wall.
DEMO_ROWS = [
    {"date": "2026-09-11T19:00:00",
     "home_team": {"school_name": "Central", "is_home": False},
     "away_team": {"school_name": "Westview", "is_home": True},
     "opponent": "Westview", "result": ""},
    {"date": "2026-09-18T19:30:00",
     "home_team": {"school_name": "Central", "is_home": True},
     "away_team": {"school_name": "Lincoln", "is_home": False},
     "opponent": "Lincoln", "result": ""},
    {"date": "2026-09-18T19:30:00",
     "home_team": {"school_name": "Central", "is_home": True},
     "away_team": {"school_name": "Lincoln", "is_home": False},
     "opponent": "Lincoln", "result": ""},
    {"date": "2026-09-26T13:00:00",
     "home_team": {"school_name": "Central", "is_home": False},
     "away_team": {"school_name": "Mountain View Prep", "is_home": True},
     "opponent": "Mountain View Prep", "result": ""},
    {"date": "2026-10-02T19:00:00",
     "home_team": {"school_name": "Central", "is_home": True},
     "away_team": {"school_name": "Roosevelt", "is_home": False},
     "opponent": "Roosevelt", "result": ""},
    {"date": "2026-10-09T19:00:00",
     "home_team": {"school_name": "Central", "is_home": False},
     "away_team": {"school_name": "North Shore", "is_home": True},
     "opponent": "North Shore", "result": ""},
]


# ------------------------------------------------------------ text helpers
def _clip(c, text, font, maxw):
    """Longest prefix of `text` that fits maxw in `font`.

    text_fit shrinks the font instead, and when even its smallest option
    overflows it still draws -- which is how a long school name ends up
    running through the date column beside it."""
    t = str(text)
    if c.text_width(t, font) <= maxw:
        return t
    for k in range(len(t), 0, -1):
        if c.text_width(t[:k], font) <= maxw:
            return t[:k]
    return ""


def _fit(c, text, fonts, maxw):
    """[font, text] for the largest listed font that fits, clipped if none do."""
    pick = fonts[len(fonts) - 1]
    for f in fonts:
        if c.text_width(text, f) <= maxw:
            pick = f
            break
    return [pick, _clip(c, text, pick, maxw)]


def nodata(c, title, sub):
    """The screen for every failure: no key, bad key, feed down, no games.

    A panel on a wall must say something sensible instead of going blank, and
    the publish-time validator renders each page with the network disabled to
    check exactly this."""
    c.fill(BG)
    c.rect(0, 0, 2, c.height - 1, fill = "#3A2E12")
    maxw = c.width - 12
    t = _fit(c, title.upper(), ["10x16_bold", "6x8", "5x7b", "4x5"], maxw)
    c.text(t[1], c.width // 2 + 1, 2, font = t[0], color = RAIL, align = "center")
    d = _fit(c, sub.upper(), ["5x7", "4x5"], maxw)
    c.text(d[1], c.width // 2 + 1, 22, font = d[0], color = TAG_OFF, align = "center")


# ------------------------------------------------------------ date helpers
def _digits(s):
    if len(s) == 0:
        return False
    for ch in s.elems():
        if ch < "0" or ch > "9":
            return False
    return True


def _ymd(s):
    """[year, month, day] from an ISO-ish or US date string, or None.

    The scraper may hand back "2026-09-11", "2026-09-11T19:00:00" or
    "9/11/2026" depending on how MaxPreps rendered the row, so all three
    parse here and anything else falls through to being shown verbatim."""
    t = str(s).strip()
    if t == "":
        return None
    if "T" in t:
        t = t.split("T")[0]
    if " " in t:
        t = t.split(" ")[0]
    if "-" in t:
        p = t.split("-")
        if len(p) == 3 and _digits(p[0]) and _digits(p[1]) and _digits(p[2]):
            return [int(p[0]), int(p[1]), int(p[2])]
    if "/" in t:
        p = t.split("/")
        if len(p) == 3 and _digits(p[0]) and _digits(p[1]) and _digits(p[2]):
            y = int(p[2])
            if y < 100:
                y = 2000 + y
            return [y, int(p[0]), int(p[1])]
    return None


def _weekday(y, m, d):
    """0=Sunday. Sakamoto's algorithm -- there is no date library here, and a
    schedule card without the day of the week is much harder to read."""
    t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
    yy = y
    if m < 3:
        yy = yy - 1
    return (yy + yy // 4 - yy // 100 + yy // 400 + t[m - 1] + d) % 7


def _rank(ymd):
    return ymd[0] * 10000 + ymd[1] * 100 + ymd[2]


def _fmt_date(ymd):
    m = ymd[1]
    if m < 1 or m > 12:
        return ""
    return DAYS[_weekday(ymd[0], m, ymd[2])] + " " + MONTHS[m - 1] + " " + str(ymd[2])


def _hhmm(s):
    """12-hour clock out of an ISO datetime like 2025-09-05T19:30:00.

    get_team_schedule ships no separate time field -- the kickoff is the
    time half of the date, so without this every card reads TIME TBA."""
    t = str(s)
    if "T" not in t:
        return ""
    bits = t.split("T")[1].split(":")
    if len(bits) < 2 or not _digits(bits[0]) or not _digits(bits[1][:2]):
        return ""
    h = int(bits[0])
    ap = "PM" if h >= 12 else "AM"
    hh = h % 12
    if hh == 0:
        hh = 12
    return str(hh) + ":" + bits[1][:2] + " " + ap


def _fmt_time(s):
    """MaxPreps times arrive as "7:00 PM", "7:00pm" or "19:00"; normalise the
    spacing so the right-hand column lines up card to card."""
    t = str(s).strip().upper().replace(".", "")
    if t == "":
        return ""
    for suf in ["PM", "AM"]:
        if t.endswith(suf) and not t.endswith(" " + suf):
            t = t[:len(t) - 2].strip() + " " + suf
    return t


# ----------------------------------------------------------- field picking
def _norm(k):
    return str(k).lower().replace("_", "").replace("-", "").replace(" ", "")


def _pick(d, names, fallback = ""):
    """First of `names` that `d` actually has, ignoring case/underscores.

    parse.bot names output fields from the scraper's plain-English task, so
    the key could be "homeTeam", "home_team" or "home team" for one column."""
    if type(d) != "dict":
        return fallback
    lut = {}
    for k in d:
        lut[_norm(k)] = d[k]
    for n in names:
        nk = _norm(n)
        if nk in lut:
            v = lut[nk]
            if v != None and str(v).strip() != "":
                return v
    return fallback


def _rows(j):
    """The list of games inside whatever wrapper the endpoint returned."""
    if type(j) == "list":
        return j
    if type(j) == "dict":
        for k in ["contests", "games", "schedule", "results", "data",
                  "events", "items", "rows"]:
            v = _pick(j, [k], None)
            if type(v) == "list":
                return v
    return None


def _truthy(v):
    return v == True or str(v).strip().lower() in ["true", "1", "yes", "y"]


def _side(v):
    """School name out of a team field that may be a string or an object.

    get_team_schedule nests each side as
    {"school_name": ..., "is_home": ...}, so a plain str() here yields the
    printed dict."""
    if type(v) == "dict":
        return str(_pick(v, ["school_name", "name", "team_name", "school"], "")).strip()
    return str(v).strip()


def _teams(g, school):
    """[away, home] for one contest.

    The trap: get_team_schedule labels the two sides home_team and
    away_team, but they actually mean "the team you asked about" and "the
    opponent" -- home_team.school_name is the requested school on every row,
    home or away, and the real venue is in is_home. Taking the field names
    at face value puts every away game on the wrong side of the card."""
    ht = _pick(g, ["home_team", "home team"], None)
    at = _pick(g, ["away_team", "away team", "visitor", "visiting team"], None)
    subj = _side(ht)
    opp = _side(at)

    if type(ht) == "dict" and subj != "" and opp != "":
        if _truthy(_pick(ht, ["is_home"], False)):
            return [opp, subj]
        return [subj, opp]

    # A feed with honest home/away columns.
    if subj != "" and opp != "":
        return [opp, subj]

    # Or a single opponent column plus a flag, sometimes only the "@" that
    # MaxPreps prints in front of the opponent.
    name = str(_pick(g, ["opponent", "opponent name", "opponent school",
                         "against", "opposing team"], "")).strip()
    if name == "":
        return None

    # Flag-ish keys only: a "venue" column holds a stadium name, and testing
    # that for a leading "H" guesses home/away at random.
    flag = str(_pick(g, ["home away", "homeoraway", "at home", "is home",
                         "site"], "")).strip().upper()
    at_home = flag.startswith("H") or flag == "TRUE" or flag.startswith("VS")
    if name.startswith("@"):
        at_home = False
        name = name[1:].strip()
    elif name.upper().startswith("VS "):
        at_home = True
        name = name[3:].strip()

    if at_home:
        return [name, school]
    return [school, name]


# ------------------------------------------------------------------ fetch
def _school(ctx):
    return str(ctx.inputs.get("school", "")).strip()


def _is_demo(ctx):
    return _school(ctx).upper() == "DEMO"


def _call(key, endpoint, params):
    """[reason, json] -- one parse.bot call with every failure mode mapped.

    parse.bot signals trouble three different ways and they must not blur
    together: a 5xx (the scrape crashed), a 422 (it rejected the input), and
    a perfectly ordinary 200 whose body says status=error."""
    r = http.get(
        BASE + SCRAPER_ID + "/" + endpoint,
        params = params,
        headers = {"X-API-Key": key},
        ttl_seconds = 43200,
    )
    code = r["status_code"]
    if code == 401 or code == 403:
        return ["KEY", None]
    if code == 404:
        return ["ENDPOINT", None]
    if code == 422:
        return ["BADPATH", None]
    if code >= 500:
        # Answered by Cloudflare as plain text, so there is no JSON to read.
        return ["SCRAPER", None]
    if code != 200 or r["json"] == None:
        return ["OFFLINE", None]
    if str(_pick(r["json"], ["status"], "")).lower() == "error":
        return ["SCRAPER", None]
    return ["OK", r["json"]]


def _games(ctx):
    """["OK", games] or [reason, None].

    Reasons: CONFIG (nothing entered), NEEDPATH (a name, not a path),
    KEY (401/403), ENDPOINT (404),
    BADPATH (422 -- parse.bot rejected the path), SCRAPER (5xx, or a 200
    carrying status=error -- the scraper ran and failed), OFFLINE
    (unreachable), EMPTY (ran fine, nothing upcoming).

    These started out as one screen, which made a broken scraper look
    exactly like a school with no games left. They are worth keeping
    apart."""
    school = _school(ctx)
    if school == "":
        return ["CONFIG", None]

    if _is_demo(ctx):
        raw = DEMO_ROWS
        school = DEMO_SCHOOL
    else:
        key = str(ctx.inputs.get("apikey", "")).strip()
        if key == "":
            return ["CONFIG", None]

        if not school.startswith("/"):
            return ["NEEDPATH", None]

        # season is optional: omitted, the endpoint serves whichever season
        # MaxPreps has marked current, which during the off-season is still
        # last year's completed schedule.
        params = {"path": school}
        season = str(ctx.inputs.get("season", "")).strip()
        if season != "":
            params["season"] = season

        res = _call(key, SCHEDULE_ENDPOINT, params)
        if res[1] == None:
            return [res[0], None]

        # The games sit under data on this API; _rows also copes with a bare
        # list or a differently-named wrapper.
        body = _pick(res[1], ["data"], None)
        raw = _rows(body if body != None else res[1])
        if raw == None or len(raw) == 0:
            return ["EMPTY", None]

    today = ctx.now.year * 10000 + ctx.now.month * 100 + ctx.now.day
    games = []
    seen = {}
    for g in raw:
        teams = _teams(g, school.upper())
        if teams == None:
            continue
        raw_date = _pick(g, ["date", "game date", "gamedate", "day", "datetime",
                             "start", "start time", "kickoff"], "")
        ymd = _ymd(raw_date)
        if ymd != None:
            if _rank(ymd) < today:
                continue  # already played
            shown = _fmt_date(ymd)
            order = _rank(ymd)
        else:
            shown = str(raw_date).strip().upper()
            order = 0
        # The feed repeats some contests verbatim (Naples' 2025 opener is in
        # there twice), which would burn two of the five game pages on the
        # same matchup.
        tag = str(order) + "|" + teams[0].upper() + "|" + teams[1].upper()
        if tag in seen:
            continue
        seen[tag] = True

        games.append({
            "away": teams[0].upper(),
            "home": teams[1].upper(),
            "date": shown,
            "time": _fmt_time(_pick(g, ["time", "game time", "kickoff",
                                        "start time"], "")) or _hhmm(raw_date),
            "order": order,
            "school": school.upper(),
        })

    if len(games) == 0:
        return ["EMPTY", None]

    # Sort by date only when every game parsed one; otherwise the feed's own
    # order is the best guess and mixing the two would shuffle it.
    datable = True
    for g in games:
        if g["order"] == 0:
            datable = False
    if datable:
        pairs = []
        for i in range(len(games)):
            pairs.append([games[i]["order"], i])
        games = [games[p[1]] for p in sorted(pairs)]

    return ["OK", games]


def _plural(n, word):
    return str(n) + " " + word + ("" if n == 1 else "S")


def _fail(c, ctx, reason):
    school = DEMO_SCHOOL if _is_demo(ctx) else _school(ctx).upper()
    if reason == "CONFIG":
        nodata(c, "SET UP APP", "ADD YOUR SCHOOL AND PARSE.BOT KEY")
    elif reason == "KEY":
        nodata(c, "CHECK KEY", "PARSE.BOT REJECTED THAT API KEY")
    elif reason == "NEEDPATH":
        nodata(c, "NEEDS A PATH", "PASTE A MAXPREPS TEAM PATH")
    elif reason == "SCRAPER":
        nodata(c, "SCRAPER DOWN", "PARSE.BOT SCRAPER IS FAILING")
    elif reason == "BADPATH":
        nodata(c, "CHECK PATH", "NEEDS A MAXPREPS TEAM PATH")
    elif reason == "ENDPOINT":
        nodata(c, "BAD ENDPOINT", "SCRAPER PATH NOT FOUND - SEE APP.STAR")
    elif reason == "EMPTY":
        if school == "":
            nodata(c, "NO GAMES", "NOTHING UPCOMING ON THE SCHEDULE")
        else:
            nodata(c, "NO GAMES", "NONE UPCOMING FOR " + school)
    else:
        nodata(c, "NO SCHEDULE", "CANT REACH PARSE.BOT RIGHT NOW")


# ------------------------------------------------------------------ layout
NAME_X = 30          # school names start here
NAME_MAXW = 90       # ... and must end before the divider at x=126
DIV_X = 126
RIGHT_X = 189        # date/time column is right-aligned to here


def _card(c, g):
    c.fill(BG)
    c.rect(0, 0, 2, c.height - 1, fill = RAIL)

    away = g["away"]
    home = g["home"]
    me = g["school"]

    # AWAY / HOME tags: the followed school's tag is lit and the opponent's
    # is dim, so a home game reads at a glance.
    c.text("AWAY", 6, 5, font = "4x5",
           color = TAG_ON if away == me else TAG_OFF)
    c.text("HOME", 6, 21, font = "4x5",
           color = TAG_ON if home == me else TAG_OFF)

    # One font for BOTH names -- real school names run long ("Mountain View",
    # "Saint Francis Prep"), and dropping to the small font is far more
    # readable than truncating, but a card with one big name and one small
    # one looks broken, so the longer name decides for both.
    nf = "5x7b"
    ny = 4
    if (c.text_width(away, nf) > NAME_MAXW or
        c.text_width(home, nf) > NAME_MAXW):
        nf = "4x5"
        ny = 5
    c.text(_clip(c, away, nf, NAME_MAXW), NAME_X, ny, font = nf,
           color = ME if away == me else OPP)
    c.text(_clip(c, home, nf, NAME_MAXW), NAME_X, ny + 16, font = nf,
           color = ME if home == me else OPP)

    c.hline(6, 15, DIV_X - 10, DIV)
    c.vline(DIV_X, 3, 28, DIV)

    date = g["date"]
    if date == "":
        date = "TBA"
    c.text(_clip(c, date, "5x7b", RIGHT_X - DIV_X - 4), RIGHT_X, 4,
           font = "5x7b", color = DATE_C, align = "right")
    tm = g["time"]
    if tm == "":
        tm = "TIME TBA"
    c.text(_clip(c, tm, "5x7", RIGHT_X - DIV_X - 4), RIGHT_X, 21,
           font = "5x7", color = TIME_C, align = "right")


def _game_page(c, ctx, n):
    res = _games(ctx)
    if res[1] == None:
        _fail(c, ctx, res[0])
        return
    games = res[1]
    if n > len(games):
        nodata(c, games[0]["school"], _plural(len(games), "GAME") + " UPCOMING")
        return
    _card(c, games[n - 1])


# ------------------------------------------------------------------- pages
def next_up(c, ctx):
    """Title card: whose schedule this is, and when the next game is."""
    res = _games(ctx)
    if res[1] == None:
        _fail(c, ctx, res[0])
        return
    g = res[1][0]

    c.fill(BG)
    c.rect(0, 0, 2, c.height - 1, fill = RAIL)

    name = _fit(c, g["school"], ["10x16_bold", "10x16", "6x8", "5x7b"], 178)
    c.text(name[1], 8, 1, font = name[0], color = ME)

    line = "FOOTBALL"
    if g["date"] != "":
        line = "NEXT " + g["date"]
        if g["time"] != "":
            line = line + "  " + g["time"]
    c.text(_clip(c, line, "5x7", 178), 8, 21, font = "5x7", color = DATE_C)


def game1(c, ctx):
    _game_page(c, ctx, 1)


def game2(c, ctx):
    _game_page(c, ctx, 2)


def game3(c, ctx):
    _game_page(c, ctx, 3)


def game4(c, ctx):
    _game_page(c, ctx, 4)


def game5(c, ctx):
    _game_page(c, ctx, 5)
