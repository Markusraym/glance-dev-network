# DESIGN. The scroll build of drb116's Disney World Parks. The left third IS
# the 64px app — the park's hand-drawn pixel wordmark, the crowd meter, and
# its landmark art (Cinderella Castle, Spaceship Earth, the Tower of Terror,
# the Tree of Life) — so the two builds are unmistakably the same app. The
# extra 128px earns its place with the thing a 64px panel can never show:
# the four longest standby waits in the park right now, names clipped at
# word boundaries, minutes color-banded (green under 30, amber under 60,
# orange under 90, red past it), under a header that also says when the
# park closes tonight. After hours the wait table becomes the hours card
# (today's and tomorrow's opening times); with no network at all the art
# and wordmark stay — they're drawn from code — beside an amber offline
# card. Rail and wordmark accents are each park's own color. Data:
# api.themeparks.wiki live standby queues + schedule, park-local (Eastern)
# time handled the same way the classic build does it.

API_BASE = "https://api.themeparks.wiki/v1/entity/"

MAGIC_KINGDOM_ID = "75ea578a-adc8-4116-a54d-dccb60765ef9"
EPCOT_ID = "47f90d2c-e191-4239-a466-5892ef59a88b"
HOLLYWOOD_STUDIOS_ID = "288747d1-8b4f-4a64-867e-ea7c9b27bad8"
ANIMAL_KINGDOM_ID = "1c84a229-8862-4648-9c71-378ddd2c7693"

STRUCT = "darkgray"        # dividers
OFFLINE = "#3C4043"        # the rail when there is no data
INK = "#F4F7FF"            # primary text
DIM = "#6E7A94"            # secondary text

# ---------------------------------------------------------
# CUSTOM PARK-NAME BITMAPS (from the classic build)
# Every character is 5 pixels tall; widths vary so I and L
# do not waste space while M and W look natural.
# ---------------------------------------------------------

MAGIC_BITMAP = [
    [1,0,0,0,1, 0, 0,1,0, 0,0,1,1,1, 0,1, 0,0,1,1],
    [1,1,0,1,1, 0, 1,0,1, 0,1,0,0,0, 0,1, 0,1,0,0],
    [1,0,1,0,1, 0, 1,1,1, 0,1,0,1,1, 0,1, 0,1,0,0],
    [1,0,0,0,1, 0, 1,0,1, 0,1,0,0,1, 0,1, 0,1,0,0],
    [1,0,0,0,1, 0, 1,0,1, 0,0,1,1,0, 0,1, 0,0,1,1],
]

KINGDOM_BITMAP = [
    [1,0,0,1, 0,1, 0,1,0,0,1, 0,0,1,1,1, 0,1,1,0, 0,1,1,1, 0,1,0,0,0,1],
    [1,0,1,0, 0,1, 0,1,1,0,1, 0,1,0,0,0, 0,1,0,1, 0,1,0,1, 0,1,1,0,1,1],
    [1,1,0,0, 0,1, 0,1,0,1,1, 0,1,0,1,1, 0,1,0,1, 0,1,0,1, 0,1,0,1,0,1],
    [1,0,1,0, 0,1, 0,1,0,0,1, 0,1,0,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,0,0,1],
    [1,0,0,1, 0,1, 0,1,0,0,1, 0,0,1,1,0, 0,1,1,0, 0,1,1,1, 0,1,0,0,0,1],
]

EPCOT_BITMAP = [
    [1,1,1, 0,1,1,1,0, 0,0,1,1, 0,1,1,1, 0,1,1,1],
    [1,0,0, 0,1,0,0,1, 0,1,0,0, 0,1,0,1, 0,0,1,0],
    [1,1,0, 0,1,1,1,0, 0,1,0,0, 0,1,0,1, 0,0,1,0],
    [1,0,0, 0,1,0,0,0, 0,1,0,0, 0,1,0,1, 0,0,1,0],
    [1,1,1, 0,1,0,0,0, 0,0,1,1, 0,1,1,1, 0,0,1,0],
]

HOLLYWOOD_BITMAP = [
    [1,0,1, 0,1,1,1, 0,1,0,0, 0,1,0,0, 0,1,0,1, 0,1,0,0,0,1, 0,1,1,1, 0,1,1,1, 0,1,1,0],
    [1,0,1, 0,1,0,1, 0,1,0,0, 0,1,0,0, 0,1,0,1, 0,1,0,0,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1],
    [1,1,1, 0,1,0,1, 0,1,0,0, 0,1,0,0, 0,0,1,0, 0,1,0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1],
    [1,0,1, 0,1,0,1, 0,1,0,0, 0,1,0,0, 0,0,1,0, 0,1,0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1],
    [1,0,1, 0,1,1,1, 0,1,1,1, 0,1,1,1, 0,0,1,0, 0,0,1,0,1,0, 0,1,1,1, 0,1,1,1, 0,1,1,0],
]

STUDIOS_BITMAP = [
    [0,1,1,1, 0,1,1,1, 0,1,0,1, 0,1,1,0, 0,1, 0,1,1,1, 0,0,1,1,1],
    [1,0,0,0, 0,0,1,0, 0,1,0,1, 0,1,0,1, 0,1, 0,1,0,1, 0,1,0,0,0],
    [0,1,1,0, 0,0,1,0, 0,1,0,1, 0,1,0,1, 0,1, 0,1,0,1, 0,1,1,1,0],
    [0,0,0,1, 0,0,1,0, 0,1,0,1, 0,1,0,1, 0,1, 0,1,0,1, 0,0,0,0,1],
    [1,1,1,0, 0,0,1,0, 0,1,1,1, 0,1,1,0, 0,1, 0,1,1,1, 0,1,1,1,0],
]

ANIMAL_BITMAP = [
    [0,1,0, 0,1,0,0,1, 0,1, 0,1,0,0,0,1, 0,0,1,0, 0,1,0,0],
    [1,0,1, 0,1,1,0,1, 0,1, 0,1,1,0,1,1, 0,1,0,1, 0,1,0,0],
    [1,1,1, 0,1,0,1,1, 0,1, 0,1,0,1,0,1, 0,1,1,1, 0,1,0,0],
    [1,0,1, 0,1,0,0,1, 0,1, 0,1,0,0,0,1, 0,1,0,1, 0,1,0,0],
    [1,0,1, 0,1,0,0,1, 0,1, 0,1,0,0,0,1, 0,1,0,1, 0,1,1,1],
]

# ---------------------------------------------------------
# HOUSE KIT
# ---------------------------------------------------------

def clip(c, text, font, maxw):
    """Longest prefix of `text` that fits `maxw` — nothing in the API clips,
    so every feed string comes through here before it is drawn."""
    t = str(text)
    if c.text_width(t, font) <= maxw:
        return t
    for k in range(len(t), 0, -1):
        if c.text_width(t[:k], font) <= maxw:
            return t[:k]
    return ""

def clip_words(c, text, font, maxw):
    """clip(), backed up to the last whole word unless that costs > 30% —
    "SEVEN DWARFS MINE TRAIN" cut mid-word reads worse than one word short."""
    t = clip(c, text, font, maxw)
    if t == str(text):
        return t
    sp = t.rfind(" ")
    if sp > 0 and sp * 10 >= len(t) * 7:
        return t[:sp]
    return t

def get(obj, key, fallback = None):
    if obj == None or type(obj) != "dict":
        return fallback
    v = obj.get(key, fallback)
    return fallback if v == None else v

def lst(obj, key):
    v = get(obj, key, [])
    return v if type(v) == "list" else []

# ---------------------------------------------------------
# DATE HELPERS (park-local Eastern time, from the classic build)
# ---------------------------------------------------------

def _is_leap_year(year):
    if year % 400 == 0:
        return True
    if year % 100 == 0:
        return False
    return year % 4 == 0

def _days_in_month(year, month):
    if month == 2:
        return 29 if _is_leap_year(year) else 28
    if month == 4 or month == 6 or month == 9 or month == 11:
        return 30
    return 31

def _two_digits(value):
    return ("0" + str(value)) if value < 10 else str(value)

def _date_key(year, month, day):
    return str(year) + "-" + _two_digits(month) + "-" + _two_digits(day)

def _next_day(year, month, day):
    day = day + 1
    if day > _days_in_month(year, month):
        day = 1
        month = month + 1
        if month > 12:
            month = 1
            year = year + 1
    return [year, month, day]

def _previous_day(year, month, day):
    day = day - 1
    if day < 1:
        month = month - 1
        if month < 1:
            month = 12
            year = year - 1
        day = _days_in_month(year, month)
    return [year, month, day]

def _day_of_week(year, month, day):
    offsets = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
    adjusted_year = year
    if month < 3:
        adjusted_year = adjusted_year - 1
    return (adjusted_year + adjusted_year // 4 - adjusted_year // 100 +
            adjusted_year // 400 + offsets[month - 1] + day) % 7

def _second_sunday_in_march(year):
    first_day = _day_of_week(year, 3, 1)
    first_sunday = 1
    if first_day != 0:
        first_sunday = 8 - first_day
    return first_sunday + 7

def _first_sunday_in_november(year):
    first_day = _day_of_week(year, 11, 1)
    if first_day == 0:
        return 1
    return 8 - first_day

def _is_eastern_daylight_time(year, month, day, utc_hour):
    start_day = _second_sunday_in_march(year)
    end_day = _first_sunday_in_november(year)
    if month < 3 or month > 11:
        return False
    if month > 3 and month < 11:
        return True
    if month == 3:
        if day > start_day:
            return True
        if day < start_day:
            return False
        return utc_hour >= 7
    if day < end_day:
        return True
    if day > end_day:
        return False
    return utc_hour < 6

def _eastern_date(now):
    year = now.year
    month = now.month
    day = now.day
    utc_hour = now.hour
    offset = 5
    if _is_eastern_daylight_time(year, month, day, utc_hour):
        offset = 4
    local_hour = utc_hour - offset
    if local_hour < 0:
        previous = _previous_day(year, month, day)
        year = previous[0]
        month = previous[1]
        day = previous[2]
    return [year, month, day]

# ---------------------------------------------------------
# API HELPERS
# ---------------------------------------------------------

def _get_json(url, ttl):
    response = http.get(url, headers = {"accept": "application/json"},
                        ttl_seconds = ttl)
    if response["status_code"] != 200:
        return None
    return response["json"]

def _get_live_data(park_id):
    # ttl 300 matches the manifest's refresh: waits move every few minutes.
    data = _get_json(API_BASE + park_id + "/live", 300)
    if data == None:
        return None
    return lst(data, "liveData")

def _get_schedule(park_id):
    data = _get_json(API_BASE + park_id + "/schedule", 1800)
    if data == None:
        return None
    return lst(data, "schedule")

def _find_operating_hours(schedule, date_key):
    for entry in schedule or []:
        if get(entry, "date", "") != date_key:
            continue
        if get(entry, "type", "") == "OPERATING":
            return entry
    return None

def _time_from_iso(value):
    """themeparks.wiki hands back park-local ISO stamps, so the hour can be
    read straight out of the string."""
    text = str(value)
    if value == None or len(text) < 16:
        return "--"
    hour = int(text[11:13])
    minute = text[14:16]
    suffix = "A" if hour < 12 else "P"
    display_hour = hour % 12
    if display_hour == 0:
        display_hour = 12
    if minute == "00":
        return str(display_hour) + suffix
    return str(display_hour) + ":" + minute + suffix

def _hours_text(hours):
    if hours == None:
        return "CLOSED"
    return _time_from_iso(get(hours, "openingTime")) + "-" + _time_from_iso(get(hours, "closingTime"))

# ---------------------------------------------------------
# CROWD CALCULATION (identical to the classic build)
# ---------------------------------------------------------

def _standby_wait(entry):
    queue = get(entry, "queue", {})
    standby = get(queue, "STANDBY")
    if standby == None:
        return None
    return get(standby, "waitTime")

def _crowd_data(live_data):
    highest_wait = -1
    second_highest_wait = -1
    wait_count = 0
    operating_count = 0
    for entry in live_data:
        if get(entry, "entityType", "") != "ATTRACTION":
            continue
        if get(entry, "status", "") != "OPERATING":
            continue
        operating_count = operating_count + 1
        wait_time = _standby_wait(entry)
        if wait_time == None:
            continue
        if wait_time < 0 or wait_time > 300:
            continue
        wait_count = wait_count + 1
        if wait_time > highest_wait:
            second_highest_wait = highest_wait
            highest_wait = wait_time
        elif wait_time > second_highest_wait:
            second_highest_wait = wait_time
    load_wait = 0
    if second_highest_wait >= 0:
        load_wait = (highest_wait + second_highest_wait) // 2
    elif highest_wait >= 0:
        load_wait = highest_wait
    return [operating_count, wait_count, load_wait]

def _crowd_level(average_wait):
    if average_wait <= 40:
        return [1, "LIGHT", "green"]
    if average_wait <= 60:
        return [2, "MILD", "#8FD14F"]
    if average_wait <= 75:
        return [3, "BUSY", "amber"]
    if average_wait <= 90:
        return [4, "HEAVY", "orange"]
    return [5, "PACKED", "red"]

def _wait_color(w):
    """Per-ride minutes band: what one wait feels like, not the whole park."""
    if w < 30:
        return "green"
    if w < 60:
        return "amber"
    if w < 90:
        return "orange"
    return "red"

def _clean_name(name):
    """Ride names, panel-ready: uppercase, slashes to spaces (the font has
    no slash worth keeping mid-name), runs of spaces collapsed."""
    t = str(name).upper()
    out = ""
    for ch in t.elems():
        out = out + (" " if ch == "/" else ch)
    parts = []
    for p in out.split(" "):
        if p != "":
            parts.append(p)
    return " ".join(parts)

def _tidy_clip(c, text, font, maxw):
    """clip_words(), then shed any punctuation the cut left dangling —
    "MILLENNIUM FALCON:" reads like a mistake; "MILLENNIUM FALCON" reads
    like a name."""
    t = clip_words(c, text, font, maxw)
    for _ in range(3):
        if len(t) > 0 and t[len(t) - 1] in [":", "-", ",", ".", "&", " ", "'"]:
            t = t[:len(t) - 1]
        else:
            break
    return t

def _top_waits(live_data):
    """The park's longest standby waits, worst first: [minutes, NAME]."""
    rows = []
    for entry in live_data:
        if get(entry, "entityType", "") != "ATTRACTION":
            continue
        if get(entry, "status", "") != "OPERATING":
            continue
        w = _standby_wait(entry)
        if w == None or w < 0 or w > 300:
            continue
        rows.append([w, _clean_name(get(entry, "name", ""))])
    return sorted(rows, key = lambda r: -r[0])

# ---------------------------------------------------------
# PARK ARTWORK (from the classic build, placed for this layout)
# ---------------------------------------------------------

def _draw_castle(c):
    c.sprite(
        "..........PRRR......\n..........P.RRR.....\n..........P.........\n..........T.........\n.........TTT........\n.........TTT....P...\n........TTTTT...PRR.\n........BBBBB...P.RR\n........BBBBB...P...\n........BBWBB...T...\n....P...BWWWB...T...\n....P...BWWWB..TTT..\n....PRR.BWWWB.TTTTT.\n....P.RRBBBBB.EBBBBB\n....T...BBBBBBEBBBBB\n....T...BBBBBBEBBBBB\n...TTT..BBBBBBEBBBBB\n...BBB.BBBBBBBEBBBBB\n...BBB.BBBBBBBEBBBBB\n..BBBBEBBBBBBBEBBBBB\n..BBBBEBBBBBBBEBBBBB\n..BBBBEBBBDDBBBBBBBB\n..BBBBBBBDDDDBBBBBBB\n..BBBBBBDDDDDDBBBBBB\n..BBBBBBDDDDDDBBBBBB\n..BBBBBBDDDDDDBBBBBB\n..BBBBBBDDDDDDBBBBBB\n..BBBBBBBBBBBBBBBBBB\n",
        44, 2,
        legend = {
            "R": "#E31B36", "P": "#8A9299", "T": "#17758A", "B": "#2557a8",
            "W": "#DDF5FF", "D": "#0A5068", "E": "#0f3470",
        },
    )

def _draw_epcot(c):
    c.sprite(
        ".......SSSSSS.......\n.....SSSSMMSSSS.....\n....SSMSSSSSSMSS....\n...SMSSSSSSSSSSMS...\n..SSSSMSSMMSSMSSSS..\n.SSSSSSSMSSMSSSSSSS.\n.SSSMSSSSSSSSSSSMSS.\nSMSSSSSSSSSSSSSSSSMS\nSSSSSSSMSSSSMSSSSSSS\nSSMSSSSSSSSSSSSSSMSS\nSSSSSSSSSSSSSSSSSSSS\nSSSSSSSMSSSSMSSSSSSS\n.SSSMSSSSSSSSSSSMSS.\n.SSSSSSSMSSMSSSSSSS.\n..SSSSMSSMMSSMSSSS..\n...SMSSSSSSSSSSMS...\n....SSMSSSSSSMSS....\n.....SSSSMMSSSS.....\n.......SSSSSS.......\n......BBBBBBBB......\n.....BBCCCCCCBB.....\n....BBCCCCCCCCBB....\n...BBBBCCCCCCBBBB...\n",
        44, 5,
        legend = {
            "S": "#DCEBF2", "M": "#AFC4CE", "B": "#244E60", "C": "#8EA8B5",
        },
    )

def _draw_tower(c):
    c.sprite(
        "..EEEE........EEEE..\n.EEEEEE......EEEEEE.\nEEEEEEEE....EEEEEEEE\nEEEEEEEE....EEEEEEEE\n.EEEEEE......EEEEEE.\n..EEEE........EEEE..\n....MMMMMMMMMMMM....\n...MMMMMMMMMMMMMM...\n...MMMMMMMMMMMMMM...\n...BCCCCCCCCCCCCB...\n...BCCCCCCCCCCCCB...\n...BCCCCCCCCCCCCB...\n.BBBBBBBBBBBBBBBBBB.\n..DDDDDDDDDDDDDDDD..\n...DDDDDDDDDDDDDD...\n...D.....DD.....D...\n..DD.....DD.....DD..\n..D......DD......D..\n.D.......DD.......D.\n",
        44, 7,
        legend = {
            "E": "#4E555B", "M": "#333333", "B": "#C9CDD0", "C": "#F4F4F4",
            "D": "#707980",
        },
    )

def _draw_tree(c):
    c.sprite(
        "............GGGGGG............\n.........GGGGGGGGGGGG.........\n.......GGGGGGHGGGGGGGGG.......\n.....GGGGGGGGGGGGHGGGGGGG.....\n....GGGHGGGGGGGGGGGGGGGGGG....\n...GGGGGGGGHGGGGGGGGHGGGGGG...\n..GGGGGGGGGGGGGGGGGGGGGGGGGG..\n.GGGGGHGGGGGGGGGGGGGGGGHGGGGG.\n.GGGGGGGGGGGHGGGGGGGGGGGGGGGG.\n..GGGGGGGGGGGGGGGGHGGGGGGGGG..\n...GGHGGGGGGGGGGGGGGGGGGGGG...\n....GGGGGGGGHGGGGGGGGGGGGG....\n.......GGGGGGGGGGGGGGGG.......\n..........BBBBBBBBBB..........\n...........BBBBBBBB...........\n..........BBBBBBBBBB..........\n.........BBBB....BBBB.........\n........BBBB......BBBB........\n.......BBBB........BBBB.......\n",
        33, 3,
        legend = {
            "G": "#4FAE3F", "H": "#76C95A", "B": "#87522E",
        },
    )

def _draw_art(c, art_type):
    if art_type == "CASTLE":
        _draw_castle(c)
    elif art_type == "EPCOT":
        _draw_epcot(c)
    elif art_type == "TOWER":
        _draw_tower(c)
    else:
        _draw_tree(c)

def _draw_park_name(c, park_name, accent):
    """The classic build's hand-set wordmarks, first line in the park's own
    color so each page is unmistakable before anything else is read."""
    if park_name == "MAGIC_KINGDOM":
        c.bitmap(MAGIC_BITMAP, 4, 1, accent)
        c.bitmap(KINGDOM_BITMAP, 4, 7, "white")
    elif park_name == "EPCOT":
        c.bitmap(EPCOT_BITMAP, 4, 1, accent)
    elif park_name == "HOLLYWOOD_STUDIOS":
        c.bitmap(HOLLYWOOD_BITMAP, 4, 1, accent)
        c.bitmap(STUDIOS_BITMAP, 4, 7, "white")
    else:
        c.bitmap(ANIMAL_BITMAP, 4, 1, accent)
        c.bitmap(KINGDOM_BITMAP, 4, 7, "white")

def _draw_crowd_meter(c, load_wait):
    crowd = _crowd_level(load_wait)
    level = crowd[0]
    label = crowd[1]
    color = crowd[2]
    c.text(label, 4, 14, font = "5x5", color = color)
    bar_heights = [3, 5, 7, 9, 11]
    for index in range(5):
        x0 = 6 + index * 5
        height = bar_heights[index]
        fill_color = "#252525"
        if index < level:
            fill_color = color
        c.rect(x0, 30 - height, x0 + 2, 30, fill = fill_color)

# ---------------------------------------------------------
# THE RIGHT ZONE: waits table / hours card / offline card
# ---------------------------------------------------------

RZ_L = 72                 # right-zone text starts here
RZ_R = 187                # ...and right-aligns here (5px from the app edge)

def _right_header(c, title, meta, meta_color):
    mw = c.text_width(meta, "4x5") if meta != "" else 0
    if meta != "":
        c.text(meta, RZ_R - mw, 1, font = "4x5", color = meta_color)
    room = (RZ_R - mw - 4 if meta != "" else RZ_R) - RZ_L
    c.text(clip(c, title, "4x5", room), RZ_L, 1, font = "4x5", color = DIM)

def _draw_waits(c, waits, closing):
    """Four rows, longest standby first. Minutes are the loud part; the ride
    name gets whatever width the minutes leave and clips at a word."""
    _right_header(c, "LONGEST WAITS", "TIL " + closing if closing != "" else "", DIM)
    y = 8
    for row in waits[:4]:
        mins = str(row[0]) + "M"
        col = _wait_color(row[0])
        mw = c.text_width(mins, "4x5")
        c.text(mins, RZ_R - mw, y, font = "4x5", color = col)
        c.text(_tidy_clip(c, row[1], "4x5", RZ_R - mw - 4 - RZ_L), RZ_L, y,
               font = "4x5", color = INK)
        y = y + 6

def _draw_hours_card(c, today_hours, tomorrow_hours):
    """After hours the table's pixels go to what a viewer wants next: when
    the gates open again. TODAY covers early mornings before rope drop."""
    _right_header(c, "PARK HOURS", "CLOSED", "red")
    y = 11
    shown = False
    if today_hours != None:
        c.text("TODAY", RZ_L, y, font = "4x5", color = DIM)
        t = _hours_text(today_hours)
        c.text(t, RZ_R - c.text_width(t, "4x5"), y, font = "4x5", color = INK)
        y = y + 8
        shown = True
    if tomorrow_hours != None:
        c.text("TMRW", RZ_L, y, font = "4x5", color = DIM)
        t = _hours_text(tomorrow_hours)
        c.text(t, RZ_R - c.text_width(t, "4x5"), y, font = "4x5", color = "amber")
        shown = True
    if not shown:
        c.text("NO HOURS POSTED", RZ_L, 14, font = "4x5", color = DIM)

def _draw_offline(c):
    mid = (RZ_L + RZ_R) // 2
    c.text("PARKS UNREACHABLE", mid, 11, font = "5x7", color = "amber",
           align = "center")
    c.text("WAITS RETURN NEXT REFRESH", mid, 23, font = "4x5", color = DIM,
           align = "center")

# ---------------------------------------------------------
# MAIN PARK DRAWING
# ---------------------------------------------------------

def _draw_park(c, ctx, park_name, park_id, art_type, accent):
    # Identity never depends on the network: rail, wordmark, and art are
    # all drawn from code before any fetch is consulted.
    c.rect(0, 0, 1, 31, fill = accent)
    _draw_park_name(c, park_name, accent)
    _draw_art(c, art_type)
    c.vline(67, 2, 28, STRUCT)

    live_data = _get_live_data(park_id)
    schedule = _get_schedule(park_id)

    if live_data == None and schedule == None:
        c.rect(0, 0, 1, 31, fill = OFFLINE)
        _draw_offline(c)
        return

    eastern = _eastern_date(ctx.now)
    tomorrow = _next_day(eastern[0], eastern[1], eastern[2])
    today_hours = _find_operating_hours(
        schedule, _date_key(eastern[0], eastern[1], eastern[2]))
    tomorrow_hours = _find_operating_hours(
        schedule, _date_key(tomorrow[0], tomorrow[1], tomorrow[2]))

    crowd = _crowd_data(live_data or [])
    operating_count = crowd[0]
    wait_count = crowd[1]
    load_wait = crowd[2]

    if operating_count >= 3 and wait_count >= 2:
        _draw_crowd_meter(c, load_wait)
        closing = ""
        if today_hours != None:
            closing = _time_from_iso(get(today_hours, "closingTime"))
            if closing == "--":
                closing = ""
        _draw_waits(c, _top_waits(live_data), closing)
    else:
        c.text("CLOSED", 4, 16, font = "5x7", color = "red")
        _draw_hours_card(c, today_hours, tomorrow_hours)

# ---------------------------------------------------------
# PAGES
# ---------------------------------------------------------

def magic_kingdom(c, ctx):
    _draw_park(c, ctx, "MAGIC_KINGDOM", MAGIC_KINGDOM_ID, "CASTLE", "#63B3FF")

def epcot(c, ctx):
    _draw_park(c, ctx, "EPCOT", EPCOT_ID, "EPCOT", "#765CFF")

def hollywood_studios(c, ctx):
    _draw_park(c, ctx, "HOLLYWOOD_STUDIOS", HOLLYWOOD_STUDIOS_ID, "TOWER",
               "#E6B84A")

def animal_kingdom(c, ctx):
    _draw_park(c, ctx, "ANIMAL_KINGDOM", ANIMAL_KINGDOM_ID, "TREE", "#55B84A")
