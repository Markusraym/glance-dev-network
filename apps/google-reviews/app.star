# DESIGN. A storefront's reputation, glanceable from across the room. Page one
# is the scorecard: the pixel Google "G" and a quiet GOOGLE REVIEWS eyebrow,
# the business name, five hand-drawn stars filled to the live rating (half
# stars included), the review count — and the rating itself as the hero,
# because that number is the whole reason the panel exists. Black ground;
# Google's four brand colors carried by a segmented rail, the G, and the
# gold of the stars.
#
# DATA — deliberately keyless for the core. Google's classic embed endpoint
# (maps.google.com/maps?cid=N&output=embed) hands back name, rating and
# review count in ~3.5 KB with no API key; the CID comes from the public
# reviews-widget redirect (search.google.com/local/reviews?placeid=X, ~800 B,
# static mapping cached a day). Review TEXTS are session-locked on every
# keyless endpoint, so this app deliberately stays a one-page scorecard.

WIDGET_URL = "https://search.google.com/local/reviews"
# The classic embed's FINAL addresses (maps.google.com/maps?..&output=embed
# just 301s here, and the render host doesn't follow redirects). The pb blob
# is the embed's own encoding — "place by CID" or "top match for a text
# query" — and its ! separators must not be percent-encoded, so the URLs are
# built by hand, never via params.
EMBED_CID_URL = "https://www.google.com/maps/embed?origin=mfe&pb=!1m3!3m2!1m1!4s{CID}!3m1!1sen!5m1!1sen"
EMBED_Q_URL = "https://www.google.com/maps/embed?origin=mfe&pb=!1m2!2m1!1s{Q}!3m1!1sen!5m1!1sen"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"

STRUCT = "darkgray"
OFFLINE = "#3C4043"
INK = "#F4F7FF"
DIM = "#6E7A94"

G_BLUE = "#4285F4"
G_RED = "#EA4335"
G_YELLOW = "#FBBC04"
G_GREEN = "#34A853"
STAR_GOLD = "#FBBC04"
STAR_TRACK = "#343A46"

# ---------------------------------------------------------------- house kit

def clip(c, text, font, maxw):
    t = str(text)
    if c.text_width(t, font) <= maxw:
        return t
    for k in range(len(t), 0, -1):
        if c.text_width(t[:k], font) <= maxw:
            return t[:k]
    return ""

def clip_words(c, text, font, maxw):
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

def dig(obj, path, fallback = None):
    cur = obj
    for key in path:
        cur = get(cur, key)
        if cur == None:
            return fallback
    return cur

def lst(obj, key):
    v = get(obj, key, [])
    return v if type(v) == "list" else []

def num(s, fallback = 0):
    t = str(s).strip()
    if t == "":
        return fallback
    for ch in t.elems():
        if ch < "0" or ch > "9":
            return fallback
    return int(t)

def thousands(n):
    """1284 -> "1,284" — counts read as counts, not codes. (No while in
    Starlark; a count is at most a handful of groups, so a bounded for.)"""
    s = str(int(n))
    out = ""
    for _ in range(4):
        if len(s) <= 3:
            break
        out = "," + s[len(s) - 3:] + out
        s = s[:len(s) - 3]
    return s + out

# ---------------------------------------------------------------- pixel art

# The Google G, 8x7, four brand colors.
G_ART = [
    "..rrrr..",
    ".rr..rr.",
    "yy......",
    "yy..bbbb",
    "yy....bb",
    ".gg..gb.",
    "..gggg..",
]
G_LEG = {"r": G_RED, "y": G_YELLOW, "b": G_BLUE, "g": G_GREEN}

# A 7x6 star; HALF is its left half, drawn over a track-colored full star.
STAR = [
    "...X...",
    "..XXX..",
    "XXXXXXX",
    ".XXXXX.",
    "..XXX..",
    ".XX.XX.",
]
STAR_HALF = [
    "...X",
    "..XX",
    "XXXX",
    ".XXX",
    "..XX",
    ".XX.",
]

def stars_row(c, x, y, rating10, step = 9):
    """Five stars filled to `rating10` (rating x 10, e.g. 41 = 4.1): full at
    >= .75 within a star, half at >= .25, track below. Returns end x."""
    for i in range(5):
        remain = rating10 - i * 10
        if remain >= 8:
            c.sprite(STAR, x, y, color = STAR_GOLD)
        elif remain >= 3:
            c.sprite(STAR, x, y, color = STAR_TRACK)
            c.sprite(STAR_HALF, x, y, color = STAR_GOLD)
        else:
            c.sprite(STAR, x, y, color = STAR_TRACK)
        x = x + step
    return x - (step - 7)

def rail(c, color = None):
    """The Google rail: four brand-color segments — or one status color."""
    if color != None:
        c.rect(0, 0, 1, 31, fill = color)
        return
    segs = [G_BLUE, G_RED, G_YELLOW, G_GREEN]
    for i in range(4):
        c.rect(0, i * 8, 1, i * 8 + 7, fill = segs[i])

def chrome(c, meta, meta_color):
    rail(c)
    c.sprite(G_ART, 4, 0, legend = G_LEG)
    mw = c.text_width(meta, "4x5") if meta != "" else 0
    if meta != "":
        c.text(meta, 185 - mw, 1, font = "4x5", color = meta_color)
    c.text("GOOGLE REVIEWS", 15, 1, font = "4x5", color = DIM)

def message(c, head, sub, head_color = "amber"):
    c.text(clip(c, head, "5x7", 150), 96, 12, font = "5x7",
           color = head_color, align = "center")
    if sub != "":
        c.text(clip(c, sub, "4x5", 160), 96, 24, font = "4x5",
               color = DIM, align = "center")

# ---------------------------------------------------------------- data

def demo_place():
    return {
        "name": "YOUR COMPANY NAME",
        "rating10": 48,
        "count": 1284,
        "demo": True,
    }


def fetch_cid(placeid):
    """Keyless hop 1: the public reviews-widget redirect leaks the CID in its
    `ludocid=` param. The place_id->CID mapping never changes: cache a day.
    Returns [cid, status_code]."""
    r = http.get(WIDGET_URL, params = {"placeid": placeid},
                 headers = {"User-Agent": UA}, ttl_seconds = 86400)
    body = r["body"]
    i = body.find("ludocid=")
    if i < 0:
        i = body.find("ludocid\\x3d")
        i = i + 11 if i >= 0 else -1
    else:
        i = i + 8
    if i < 0:
        return [None, r["status_code"]]
    cid = ""
    for ch in body[i:i + 25].elems():
        if ch >= "0" and ch <= "9":
            cid += ch
        else:
            break
    return [cid if cid != "" else None, r["status_code"]]

def fetch_body(url):
    """One embed fetch; None means unreachable. 30 min matches how often
    Google recomputes the public rating."""
    r = http.get(url, headers = {"User-Agent": UA}, ttl_seconds = 1800)
    if r["status_code"] != 200:
        return None
    return r["body"]

def first_list_cid(body):
    """A query matching SEVERAL places (chains: "Starbucks Hollywood FL")
    makes the embed return a result LIST, not one place. Each entry opens
    [["<featureid>","<CID>"],"/g/.. — take the top match's CID so a second
    embed-by-CID hop resolves it. Verified against the single-place payload:
    the second id is the CID there too."""
    i = body.find('[[["')
    if i < 0:
        return None
    seg = body[i + 4:i + 64]
    j = seg.find('","')
    if j < 0:
        return None
    k = seg.find('"', j + 3)
    if k < 0:
        return None
    cid = seg[j + 3:k]
    if len(cid) < 10:
        return None
    for ch in cid.elems():
        if ch < "0" or ch > "9":
            return None
    return cid

def parse_place(body):
    """The single-place embed payload. ~3.5 KB containing
    ..,"Short Name",["addr lines"],RATING,"N reviews","https://search.google..
    which is everything the scorecard needs — plus the Place ID (inside the
    widget URL), which feeds the optional review-texts page."""
    p = body.find(',"https://search.google.com/local/reviews')
    if p < 0:
        return None            # no single matched place (region result, typo)
    q = body.rfind(',"', 0, p)
    if q < 0:
        return None
    count = num(body[q + 2:p - 1].split(" ")[0].replace(",", ""), -1)
    # The embed serializes 4.1 as 4.099999904632568 — parse as float and
    # round to one decimal, or the panel under-reports every rating.
    rs = body.rfind(",", 0, q) + 1
    whole = num(body[rs:rs + 1], -1)
    if whole < 0 or count < 0:
        return None
    rating10 = int(float(body[rs:q]) * 10.0 + 0.5)
    # Walk backward from the rating: ..,"Short Name",["addr1","addr2"],RATING
    # — works whether or not we knew the CID in advance (text-query mode).
    name = ""
    o = body.rfind(",[", 0, rs - 2)
    if o > 0 and body[o - 1:o] == '"':
        n1 = body.rfind('"', 0, o - 1)
        if n1 >= 0:
            name = body[n1 + 1:o - 1]
    return {
        "name": name.upper(),
        "rating10": rating10,
        "count": count,
        "demo": False,
    }

def _words(s, minlen):
    """Alphabetic words of at least `minlen` letters, minus glue words."""
    out = []
    word = ""
    for ch in (str(s).upper() + " ").elems():
        if ch >= "A" and ch <= "Z":
            word += ch
        else:
            if len(word) >= minlen and word not in ["THE", "AND"]:
                out.append(word)
            word = ""
    return out

def query_overlap(ctx, matched_name):
    """Shared meaningful words between the user's query and the matched
    business name, checked BOTH ways ("Le Tub Saloon" matching "LE TUB"
    counts via TUB). 0 = probably the wrong business."""
    biz = str(ctx.inputs.get("business", "")).upper()
    if biz.startswith("CHIJ"):
        return 1   # exact-ID mode can't mismatch
    hits = 0
    for w in _words(biz, 4):
        if matched_name.find(w) >= 0:
            hits += 1
    for w in _words(matched_name, 3):
        if biz.find(w) >= 0:
            hits += 1
    return hits

def query_encode(q):
    """A business name + city as the embed's query token: spaces to +, and
    only characters that can't break the pb blob survive."""
    out = ""
    for ch in q.elems():
        if ch == " ":
            out += "+"
        elif (ch >= "0" and ch <= "9") or (ch >= "A" and ch <= "Z") or \
             (ch >= "a" and ch <= "z") or ch in [",", ".", "-", "'"]:
            out += ch
    return out

def load_place(ctx):
    """[place, err]: demo when the input is blank; a ChIJ.. Place ID takes
    the widget->CID->embed chain; anything else ("Joe's Pizza Austin TX")
    is a text query the embed resolves to its top match — no key either way.
    err: "offline" or "notfound"."""
    biz = str(ctx.inputs.get("business", "")).strip()
    if biz == "":
        return [demo_place(), None]
    if biz.startswith("ChIJ") and biz.find(" ") < 0:
        cid, status = fetch_cid(biz)
        if cid == None:
            return [None, "offline" if status == 0 else "notfound"]
        body = fetch_body(EMBED_CID_URL.replace("{CID}", cid))
        if body == None:
            return [None, "offline"]
        place = parse_place(body)
        return [place, None] if place != None else [None, "offline"]
    q = query_encode(biz)
    if q == "":
        return [None, "notfound"]
    body = fetch_body(EMBED_Q_URL.replace("{Q}", q))
    if body == None:
        return [None, "offline"]
    place = parse_place(body)
    if place == None:
        # Several matches came back — resolve the top one by CID.
        cid = first_list_cid(body)
        if cid != None:
            body2 = fetch_body(EMBED_CID_URL.replace("{CID}", cid))
            if body2 == None:
                return [None, "offline"]
            place = parse_place(body2)
    if place == None:
        return [None, "notfound"]
    return [place, None]

# ---------------------------------------------------------------- pages

def rating(c, ctx):
    place, err = load_place(ctx)

    if place == None:
        chrome(c, "", DIM)
        rail(c, OFFLINE)
        if err == "notfound":
            message(c, "BUSINESS NOT FOUND", "TRY NAME PLUS CITY AND STATE")
        else:
            message(c, "GOOGLE UNREACHABLE", "RATING RETURNS NEXT REFRESH")
        return

    # Google fuzzy-matches aggressively (a nonsense query still returns the
    # nearest similar-sounding business), so when the matched name shares no
    # word with what the user typed, say so instead of quietly showing a
    # stranger's rating.
    meta = "DEMO" if place["demo"] else ""
    if not place["demo"] and query_overlap(ctx, place["name"]) == 0:
        meta = "CHECK MATCH"
    chrome(c, meta, "amber")

    # Business name — a whole name in a smaller font beats a clipped name in
    # a big one ("ALL COMPUTER TECHNIQUES" fits 4x7; "ALL COMPUTER" told
    # nobody anything). Ladder down, clip at a word only as the last resort,
    # then shed any punctuation the cut left dangling.
    nfont = "4x7"
    for f in ["6x8", "5x7", "4x7"]:
        if c.text_width(place["name"], f) <= 118:
            nfont = f
            break
    name = clip_words(c, place["name"], nfont, 118)
    for _ in range(3):
        if len(name) > 0 and name[len(name) - 1] in ["-", ",", "&", ".", " "]:
            name = name[:len(name) - 1]
        else:
            break
    c.text(name, 6, 11, font = nfont, color = INK)

    # Stars + count along the bottom band.
    x = stars_row(c, 6, 23, place["rating10"])
    c.text(clip(c, thousands(place["count"]) + " REVIEWS", "4x5", 128 - x),
           x + 6, 24, font = "4x5", color = DIM)

    # The hero: the rating, right-aligned, with its scale beneath so the
    # number can never read as a magic 4.1-of-anything.
    r = place["rating10"]
    c.text(str(r // 10) + "." + str(r % 10), 185, 6, font = "16x20",
           color = INK, align = "right")
    c.text("OUT OF 5", 185, 27, font = "4x5", color = DIM, align = "right")
