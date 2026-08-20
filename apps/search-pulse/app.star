# Search Pulse — currently surging Google Search queries on a 192x32 panel.
#
# Official sources (no API key):
#   https://trends.google.com/trending?geo={US}&hours={4|24}&sort=search-volume
#     public Trending Now HTML (server-rendered table). Ranked by volume.
#   https://trends.google.com/trending/rss?geo={US}
#     Export > RSS feed. A small recency slice (often 200+/500+). Fallback only.
# The sparkline is time-aligned to the selected window from start time +
# Active/Ended. Explore CSV / private RPCs are not used.
#
# This is Google Trends Trending Now (queries with a recent surge), NOT
# overall / all-time Google search rankings. #1 means the highest-volume
# row among the parsed Trending Now results, not the most-searched word
# on Google.
#
# Starlark has no XML/XPath module. Tags are pulled with string finds.
# Frames are still images; the panel advances on the manifest refresh timer.
#
# Search Pulse is not affiliated with or endorsed by Google.

HEADERS = {
    "User-Agent": "GlanceSearchPulse/1.0 (GDN; Google Trends display)",
    "Accept": "text/html, application/xhtml+xml;q=0.9, application/rss+xml, application/xml, text/xml;q=0.8, */*;q=0.7",
    "Accept-Language": "en-US,en;q=0.9",
}

PAGE = "https://trends.google.com/trending"
FEED = "https://trends.google.com/trending/rss"
TTL = 600
WANT = 5
HTML_POOL = 25

GEO = {
    "UNITED STATES": "US",
    "CANADA": "CA",
    "UNITED KINGDOM": "GB",
    "AUSTRALIA": "AU",
    "MEXICO": "MX",
}

GEO_LABEL = {
    "US": "US",
    "CA": "CA",
    "GB": "UK",
    "AU": "AU",
    "MX": "MX",
}

MONTH = {
    "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
    "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12,
}

ENTITIES = [
    ["&amp;", "&"], ["&#39;", "'"], ["&apos;", "'"],
    ["&quot;", "\""], ["&lt;", "<"], ["&gt;", ">"], ["&nbsp;", " "],
]

ACCENT = [
    ["Á", "A"], ["À", "A"], ["Â", "A"], ["Ã", "A"], ["Ä", "A"],
    ["á", "A"], ["à", "A"], ["â", "A"], ["ã", "A"], ["ä", "A"],
    ["É", "E"], ["È", "E"], ["Ê", "E"], ["Ë", "E"],
    ["é", "E"], ["è", "E"], ["ê", "E"], ["ë", "E"],
    ["Í", "I"], ["Ì", "I"], ["Î", "I"], ["Ï", "I"],
    ["í", "I"], ["ì", "I"], ["î", "I"], ["ï", "I"],
    ["Ó", "O"], ["Ò", "O"], ["Ô", "O"], ["Õ", "O"], ["Ö", "O"],
    ["ó", "O"], ["ò", "O"], ["ô", "O"], ["õ", "O"], ["ö", "O"],
    ["Ú", "U"], ["Ù", "U"], ["Û", "U"], ["Ü", "U"],
    ["ú", "U"], ["ù", "U"], ["û", "U"], ["ü", "U"],
    ["Ñ", "N"], ["ñ", "N"], ["Ç", "C"], ["ç", "C"],
    ["Ý", "Y"], ["ý", "Y"], ["Å", "A"], ["å", "A"], ["Ø", "O"], ["ø", "O"],
]

FONTH = {"10x16": 16, "6x8": 8, "5x7": 7, "4x5": 6}

BG = "#06070E"
ACCENT_DEF = "#3CF0FF"
TITLE = "#F3F6FF"
VOL = "#FFBF00"
DIM = "#6E7A94"
MUTED = "#9AA3BB"
GROW = "#FF8A3C"

# 9x9 magnifying glass. Not a Google logo.
GLASS = [
    [0, 0, 1, 1, 1, 0, 0, 0, 0],
    [0, 1, 0, 0, 0, 1, 0, 0, 0],
    [1, 0, 0, 0, 0, 0, 1, 0, 0],
    [1, 0, 0, 0, 0, 0, 1, 0, 0],
    [1, 0, 0, 0, 0, 0, 1, 0, 0],
    [0, 1, 0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 1, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 1, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 1],
]


def _s(ctx, key, fallback):
    v = ctx.inputs.get(key, fallback)
    if v == None:
        return fallback
    return str(v).strip()


def geo_code(ctx):
    raw = _s(ctx, "country", "UNITED STATES").upper()
    code = GEO.get(raw, "")
    if code != "":
        return code
    return "US"


def window_hours(ctx):
    raw = _s(ctx, "window", "24 HOURS").upper()
    if raw.find("4") == 0 or raw.find("4 ") == 0 or raw == "4 HOURS" or raw == "4H":
        return 4
    return 24


def win_tag(hours):
    if hours == 4:
        return "4H"
    return "24H"


def accent_of(ctx):
    v = ctx.inputs.get("accent", ACCENT_DEF)
    if v == None:
        return ACCENT_DEF
    s = str(v).strip()
    if s == "":
        return ACCENT_DEF
    return s


def collapse_ws(s):
    s = str(s).replace("\n", " ").replace("\r", " ").replace("\t", " ")
    for _ in range(40):
        if s.find("  ") < 0:
            break
        s = s.replace("  ", " ")
    return s.strip()


def decode(s):
    out = str(s)
    out = out.replace("<![CDATA[", "").replace("]]>", "")
    for e in ENTITIES:
        out = out.replace(e[0], e[1])
    for a in ACCENT:
        out = out.replace(a[0], a[1])
    out = out.replace("–", "-").replace("—", "-").replace("’", "'")
    out = out.replace("‘", "'").replace("“", "\"").replace("”", "\"")
    return collapse_ws(out)


def strip_tags(s):
    out = ""
    i = 0
    n = len(s)
    for _ in range(n + 1):
        if i >= n:
            break
        lt = s.find("<", i)
        if lt < 0:
            out = out + s[i:]
            break
        out = out + s[i:lt]
        gt = s.find(">", lt)
        if gt < 0:
            break
        i = gt + 1
    return out


def xml_text(body, tag):
    close = "</" + tag + ">"
    open1 = "<" + tag + ">"
    start = body.find(open1)
    if start >= 0:
        start = start + len(open1)
    else:
        open2 = "<" + tag + " "
        p = body.find(open2)
        if p < 0:
            return ""
        gt = body.find(">", p)
        if gt < 0:
            return ""
        start = gt + 1
    end = body.find(close, start)
    if end < 0:
        return ""
    return decode(strip_tags(body[start:end]))


def to_int(s):
    t = str(s).strip()
    out = ""
    for i in range(len(t)):
        ch = t[i]
        if ch.isdigit():
            out = out + ch
        else:
            break
    if out == "":
        return 0
    return int(out)


def traffic_n(s):
    t = str(s).upper().replace(",", "").replace("+", "").strip()
    mul = 1
    if t.endswith("K"):
        mul = 1000
        t = t[:-1]
    elif t.endswith("M"):
        mul = 1000000
        t = t[:-1]
    return to_int(t) * mul


def days_from_civil(y, m, d):
    yy = y - 1 if m <= 2 else y
    era = yy // 400
    yoe = yy - era * 400
    mm = m + (-3 if m > 2 else 9)
    doy = (153 * mm + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468


def pub_unix(pub):
    # RSS: "Sat, 15 Aug 2026 12:30:00 -0700"
    raw = collapse_ws(str(pub)).replace(",", "")
    parts = raw.split(" ")
    if len(parts) < 5:
        return 0
    day = 0
    month = 0
    year = 0
    hms = ""
    off = ""
    for p in parts:
        up = p.upper()
        if MONTH.get(up, 0) > 0:
            month = MONTH[up]
        elif day == 0 and to_int(p) >= 1 and to_int(p) <= 31 and p.find(":") < 0 and len(p) <= 2:
            day = to_int(p)
        elif year == 0 and to_int(p) >= 2000 and len(p) == 4:
            year = to_int(p)
        elif hms == "" and p.find(":") >= 0:
            hms = p
        elif off == "" and len(p) == 5 and (p[0] == "+" or p[0] == "-"):
            off = p
    if day < 1 or month < 1 or year < 1 or hms == "":
        return 0
    hp = hms.split(":")
    if len(hp) < 2:
        return 0
    hh = to_int(hp[0])
    mi = to_int(hp[1])
    se = 0
    if len(hp) >= 3:
        se = to_int(hp[2])
    days = days_from_civil(year, month, day)
    local = days * 86400 + hh * 3600 + mi * 60 + se
    sign = 1
    oh = 0
    om = 0
    if off != "":
        if off[0] == "-":
            sign = -1
        oh = to_int(off[1:3])
        om = to_int(off[3:5])
    return local - sign * (oh * 3600 + om * 60)


def ago_label(ctx, pub):
    u = pub_unix(pub)
    if u <= 0:
        return ""
    now = ctx.now.unix
    delta = now - u
    if delta < 0:
        delta = 0
    mins = delta // 60
    if mins < 60:
        return str(mins) + "M AGO"
    hours = mins // 60
    if hours < 48:
        return str(hours) + "H AGO"
    return str(hours // 24) + "D AGO"


def ago_hours(s):
    t = str(s).upper().replace(" ", "").replace("AGO", "")
    if t.endswith("H"):
        return to_int(t)
    if t.endswith("M"):
        n = to_int(t)
        if n >= 60:
            return n // 60
        return 0
    if t.endswith("D"):
        return to_int(t) * 24
    return -1


def surge_series(started_h, window, active):
    # Time-aligned surge sketch for the selected window.
    # Google does not put Explore time-series samples in the public HTML;
    # SVG sparklines are filled later by JS. X is the window (left=then, right=now).
    # Spike sits at the published start time. Active stays elevated; Ended decays.
    n = 48
    if window < 1:
        window = 24
    ah = started_h
    if ah < 0:
        ah = window // 3
    if ah > window:
        spike = 0
    else:
        spike = ((window - ah) * (n - 1)) // window
    out = []
    for i in range(n):
        if i < spike - 1:
            out.append(4)
        elif i == spike - 1:
            out.append(22)
        elif i == spike:
            out.append(100)
        else:
            dist = i - spike
            if active:
                v = 28 + (72 * 5) // (5 + dist)
            else:
                v = 4 + (96 * 3) // (3 + dist)
            if v > 100:
                v = 100
            out.append(v)
    return out


def attach_series(rows, window):
    for r in rows:
        ah = ago_hours(r.get("ago", ""))
        active = r.get("status", "") != "ENDED"
        r["series"] = surge_series(ah, window, active)
    return rows


def parse_items(body, want):
    out = []
    rest = body
    for _ in range(20):
        if len(out) >= want:
            break
        a = rest.find("<item")
        if a < 0:
            break
        rest = rest[a + 5:]
        end = rest.find("</item>")
        if end < 0:
            break
        block = rest[:end]
        rest = rest[end + 7:]
        title = xml_text(block, "title")
        if title == "":
            continue
        traffic = xml_text(block, "ht:approx_traffic")
        pub = xml_text(block, "pubDate")
        out.append({
            "title": title,
            "traffic": traffic,
            "pub": pub,
            "growth": "",
            "status": "",
            "ago": "",
            "n": traffic_n(traffic),
        })
    return out


def skip_title(cand):
    t = cand.strip()
    if t == "" or len(t) >= 80 or t.find("<") >= 0:
        return True
    up = t.upper()
    if up == "ACTIVE" or up == "ENDED" or up == "LASTED":
        return True
    if up == "TRENDING_UP" or up == "ARROW_UPWARD" or up == "SEARCHES":
        return True
    if up.endswith(" AGO") or up.endswith("AGO"):
        return True
    if t == "·" or t == "&middot;":
        return True
    return False


def html_title_before(before):
    chunk = before
    for _ in range(12):
        te = chunk.rfind("</div>")
        if te < 0:
            return ""
        ts = chunk.rfind(">", 0, te)
        if ts < 0:
            return ""
        cand = decode(chunk[ts + 1:te])
        chunk = chunk[:ts]
        if skip_title(cand) == False:
            return cand
    return ""


def html_growth(after):
    gi = after.find("%")
    if gi < 1:
        return ""
    gs = gi
    for _ in range(12):
        if gs <= 0:
            break
        ch = after[gs - 1]
        if ch.isdigit() or ch == "," or ch == "+":
            gs = gs - 1
        else:
            break
    raw = after[gs:gi + 1].replace(",", "").replace(" ", "")
    if raw == "" or raw == "%":
        return ""
    if raw[0] != "+":
        raw = "+" + raw
    return raw.upper()


def html_ago(after):
    ai = after.find(" ago</div>")
    if ai < 0:
        return ""
    as_ = after.rfind(">", 0, ai)
    if as_ < 0:
        return ""
    return decode(after[as_ + 1:ai + 4]).upper()


def parse_html(body, want):
    # Public Trending Now HTML. Volume cells look like: 1M+ searches
    out = []
    rest = str(body)
    marker = " searches</div>"
    for _ in range(80):
        if len(out) >= want:
            break
        p = rest.find(marker)
        if p < 0:
            break
        left = rest.rfind(">", 0, p)
        vol = ""
        if left >= 0:
            vol = decode(rest[left + 1:p])
        title = ""
        if left >= 0:
            title = html_title_before(rest[:left])
        after = rest[p:p + 1200]
        if title != "" and vol != "":
            status = ""
            if after.find(">Active</div>") >= 0:
                status = "ACTIVE"
            elif after.find(">Ended</div>") >= 0 or after.find(">Lasted</div>") >= 0:
                status = "ENDED"
            out.append({
                "title": title,
                "traffic": vol,
                "pub": "",
                "growth": html_growth(after),
                "status": status,
                "ago": html_ago(after),
                "n": traffic_n(vol),
            })
        rest = rest[p + len(marker):]
    return out


def sort_by_n(rows):
    n = len(rows)
    for _ in range(n):
        swapped = 0
        for j in range(n - 1):
            if rows[j]["n"] < rows[j + 1]["n"]:
                tmp = rows[j]
                rows[j] = rows[j + 1]
                rows[j + 1] = tmp
                swapped = 1
        if swapped == 0:
            break
    return rows


def take(rows, n):
    if len(rows) <= n:
        return rows
    out = []
    for i in range(n):
        out.append(rows[i])
    return out


def load_trends(ctx):
    geo = geo_code(ctx)
    hours = window_hours(ctx)
    page = PAGE + "?geo=" + geo + "&hours=" + str(hours) + "&sort=search-volume&hl=en-US"
    r = http.get(page, headers = HEADERS, ttl_seconds = TTL)
    body = r["body"]
    if body == None:
        body = ""
    rows = []
    if r["status_code"] == 200 and body != "":
        rows = sort_by_n(parse_html(body, HTML_POOL))
        rows = take(rows, WANT)
        rows = attach_series(rows, hours)
    if rows != []:
        return geo, hours, rows

    rss = FEED + "?geo=" + geo
    r2 = http.get(rss, headers = HEADERS, ttl_seconds = TTL)
    body2 = r2["body"]
    if body2 == None:
        body2 = ""
    if r2["status_code"] != 200 or body2 == "":
        return geo, hours, []
    rows = sort_by_n(parse_items(body2, 10))
    rows = take(rows, WANT)
    for r in rows:
        if str(r.get("ago", "")).strip() == "":
            r["ago"] = ago_label(ctx, r.get("pub", ""))
    rows = attach_series(rows, hours)
    return geo, hours, rows


def join_words(words, a, b):
    out = words[a]
    for i in range(a + 1, b):
        out = out + " " + words[i]
    return out


def wrap2(c, text, font, maxw):
    w = c.text_width(text, font)
    words = text.split(" ")
    if w <= maxw and (w + 20 <= maxw or len(words) < 2):
        return [text]
    if len(words) < 2:
        return []
    best = []
    best_score = 100000
    for i in range(1, len(words)):
        a = join_words(words, 0, i)
        b = join_words(words, i, len(words))
        wa = c.text_width(a, font)
        wb = c.text_width(b, font)
        if wa <= maxw and wb <= maxw:
            score = wa - wb
            if score < 0:
                score = -score
            if best == [] or score < best_score:
                best = [a, b]
                best_score = score
    if best != []:
        return best
    if w <= maxw:
        return [text]
    return []


def wrap_greedy(c, text, font, maxw):
    words = text.split(" ")
    if len(words) == 0 or words == [""]:
        return []
    if c.text_width(words[0], font) > maxw:
        return []
    lines = []
    cur = words[0]
    for i in range(1, len(words)):
        cand = cur + " " + words[i]
        if c.text_width(cand, font) <= maxw:
            cur = cand
        else:
            lines.append(cur)
            cur = words[i]
            if c.text_width(cur, font) > maxw:
                return []
            if len(lines) >= 3:
                return lines
    lines.append(cur)
    return lines


def clip_line(c, text, font, maxw):
    if c.text_width(text, font) <= maxw:
        return text
    for k in range(len(text), 0, -1):
        t = text[:k] + ".."
        if c.text_width(t, font) <= maxw:
            return t
    return ""


def fit_query(c, text, maxw, maxh):
    raw = decode(text).upper()
    if raw == "":
        return ["?"], "5x7"
    one = ["10x16", "6x8", "5x7"]
    for font in one:
        h = FONTH[font]
        if h <= maxh and c.text_width(raw, font) <= maxw:
            return [raw], font
    two = ["6x8", "5x7", "4x5"]
    for font in two:
        h = FONTH[font]
        if h * 2 + 1 > maxh:
            continue
        lines = wrap2(c, raw, font, maxw)
        if lines != []:
            return lines, font
    three = ["5x7", "4x5"]
    for font in three:
        h = FONTH[font]
        if h * 3 + 2 > maxh:
            continue
        lines = wrap_greedy(c, raw, font, maxw)
        if lines != [] and len(lines) <= 3:
            ok = True
            for ln in lines:
                if c.text_width(ln, font) > maxw:
                    ok = False
            if ok:
                return lines, font
    font = "4x5"
    lines = wrap_greedy(c, raw, font, maxw)
    if lines == []:
        return [clip_line(c, raw, font, maxw)], font
    n = maxh // (FONTH[font] + 1)
    if n < 1:
        n = 1
    if n > len(lines):
        n = len(lines)
    out = []
    for i in range(n):
        line = lines[i]
        if i == n - 1 and n < len(lines):
            line = clip_line(c, line, font, maxw)
        else:
            line = clip_line(c, line, font, maxw)
        out.append(line)
    return out, font


def draw_fallback(c, title, sub, accent):
    c.fill(BG)
    c.rect(0, 0, 1, c.height - 1, fill = accent)
    c.bitmap(GLASS, 8, 4, color = accent)
    t = title.upper()
    s = sub.upper()
    c.text_fit(t, 22, 4, ["10x16", "6x8", "5x7"], color = TITLE, maxw = 166)
    c.text_fit(s, 22, 22, ["5x7", "4x5"], color = DIM, maxw = 166)


def series_y(val, gy, gh):
    bottom = gy + gh - 1
    span = gh - 1
    if span < 1:
        return bottom
    v = val
    if v < 0:
        v = 0
    if v > 100:
        v = 100
    return bottom - (v * span) // 100


def draw_chart(c, series, gx, gy, gw, gh, accent):
    if series == None or series == [] or gw < 8 or gh < 3:
        return
    c.hline(gx, gy + gh - 1, gw, color.dim(accent, 28))
    c.sparkline(series, gx, gy, gw, gh, color = accent,
                fill = color.dim(accent, 40), min_val = 0, max_val = 100)
    last = series[len(series) - 1]
    c.fill_circle(gx + gw - 1, series_y(last, gy, gh), 1, accent)


def row_ago(ctx, row):
    a = str(row.get("ago", "")).strip()
    if a != "":
        return a.upper()
    return ago_label(ctx, row.get("pub", ""))


def draw_intro(c, ctx, geo, hours, rows):
    accent = accent_of(ctx)
    c.fill(BG)
    c.rect(0, 0, 1, c.height - 1, fill = accent)
    c.bitmap(GLASS, 7, 2, color = accent)
    c.text("SEARCH PULSE", 20, 2, font = "6x8", color = TITLE)
    right = GEO_LABEL.get(geo, geo) + "  " + win_tag(hours)
    c.text(right, c.width - 4, 3, font = "4x5", color = MUTED, align = "right")

    series = []
    if rows != []:
        series = rows[0].get("series", [])
    draw_chart(c, series, 20, 12, 168, 11, accent)

    c.text("GOOGLE TRENDS", 20, 25, font = "4x5", color = MUTED)
    foot = ""
    if rows != []:
        foot = str(rows[0].get("traffic", "")).upper()
    if foot == "":
        foot = GEO_LABEL.get(geo, geo)
    c.text(foot, c.width - 4, 25, font = "4x5", color = VOL, align = "right")


def draw_trend(c, ctx, idx):
    accent = accent_of(ctx)
    geo, hours, rows = load_trends(ctx)
    if rows == []:
        draw_fallback(c, "SEARCH PULSE", "TREND DATA UNAVAILABLE", accent)
        return
    if idx >= len(rows):
        draw_fallback(c, "NO TREND " + str(idx + 1), "FEED HAS " + str(len(rows)), accent)
        return

    row = rows[idx]
    c.fill(BG)
    c.rect(0, 0, 1, c.height - 1, fill = accent)

    rank = "#" + str(idx + 1)
    c.text(rank, 6, 1, font = "10x16", color = accent)

    traffic = str(row["traffic"]).upper()
    if traffic == "":
        traffic = "--"
    c.text(traffic, 6, 18, font = "5x7", color = VOL)

    growth = str(row.get("growth", "")).upper()
    ago = row_ago(ctx, row)
    left_foot = growth
    if left_foot == "" and row.get("status", "") == "ACTIVE":
        left_foot = "ACTIVE"
    elif left_foot == "" and row.get("status", "") == "ENDED":
        left_foot = "ENDED"
    elif left_foot == "" and ago != "":
        left_foot = ago
    if left_foot != "":
        c.text(left_foot, 6, 26, font = "4x5", color = GROW)

    c.vline(44, 1, 30, color.dim(accent, 22))

    title_x = 48
    title_w = c.width - title_x - 4
    lines, font = fit_query(c, row["title"], title_w, 9)
    h = FONTH[font]
    for i in range(len(lines)):
        c.text(lines[i], title_x, 1 + i * (h + 1), font = font, color = TITLE)

    draw_chart(c, row.get("series", []), title_x, 11, title_w, 12, accent)

    if ago != "" and left_foot != ago:
        c.text(ago, title_x, 25, font = "4x5", color = MUTED)
    c.text(win_tag(hours), c.width - 4, 25, font = "4x5", color = DIM, align = "right")


def pulse(c, ctx):
    geo, hours, rows = load_trends(ctx)
    if rows == []:
        draw_fallback(c, "SEARCH PULSE", "TREND DATA UNAVAILABLE", accent_of(ctx))
        return
    draw_intro(c, ctx, geo, hours, rows)


def one(c, ctx):
    draw_trend(c, ctx, 0)


def two(c, ctx):
    draw_trend(c, ctx, 1)


def three(c, ctx):
    draw_trend(c, ctx, 2)


def four(c, ctx):
    draw_trend(c, ctx, 3)


def five(c, ctx):
    draw_trend(c, ctx, 4)
