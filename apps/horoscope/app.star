# Horoscope — one-frame daily vibe for a configured zodiac sign (192x32).
#
# Data: Free Horoscope API (https://freehoroscopeapi.com/) daily endpoint.
# No API key. GDN http.get is server-side. A User-Agent is required.
#
# Glance rotates apps ~every 3s, so this is a punchline frame — glyph + sign
# + TODAY + a short finished sentence from the daily reading (fits on-panel).
#
# Bitmap fonts are UPPERCASE ONLY. Glyph art: assets/{sign}.png.

API_URL = "https://freehoroscopeapi.com/api/v1/get-horoscope/daily"

# id -> [display name, accent color]
SIGNS = {
    "ARIES": ["ARIES", "#FF4628"],
    "TAURUS": ["TAURUS", "#28E65A"],
    "GEMINI": ["GEMINI", "#FFD228"],
    "CANCER": ["CANCER", "#46AAFF"],
    "LEO": ["LEO", "#FFB41E"],
    "VIRGO": ["VIRGO", "#8CE632"],
    "LIBRA": ["LIBRA", "#FF64BE"],
    "SCORPIO": ["SCORPIO", "#FF2D5A"],
    "SAGITTARIUS": ["SAGITTARIUS", "#AA64FF"],
    "CAPRICORN": ["CAPRICORN", "#DCB050"],
    "AQUARIUS": ["AQUARIUS", "#1ED2FF"],
    "PISCES": ["PISCES", "#28F0DC"],
}

# Prefer readable fonts; allow up to 3 lines so a full first sentence can finish.
# Vertical budget: BODY_Y + (n-1)*lh + font_h must stay inside the 32px panel.
TIERS = [["5x7", 8], ["4x5", 6], ["picopixel", 6]]
FONT_H = {"5x7": 7, "4x5": 5, "picopixel": 5}
BODY_Y = 10
MAX_LINES = 3
# Leave 1px clear of the bottom edge so glyphs never bleed under the frame.
PANEL_BOTTOM = 31


def safe_input(ctx, key, default):
    value = ctx.inputs.get(key, default)
    if value == None or value == "":
        return default
    return value


def resolve_sign(raw):
    key = str(raw).upper().strip()
    if key in SIGNS:
        return key
    return "ARIES"


def tighten(text, name):
    # Drop openers the header already covers.
    t = str(text).upper().strip()
    prefixes = [
        "FOR " + name + "S TODAY",
        "FOR " + name + " TODAY",
        "FOR " + name + "S",
        "FOR " + name,
        name + "S TODAY",
        name + " TODAY",
        name + "S:",
        name + ":",
        name + "S",
        name,
    ]
    for p in prefixes:
        if t.startswith(p):
            t = t[len(p):].strip()
            break
    for _ in range(8):
        if len(t) == 0 or t[0] not in " ,.-:;":
            break
        t = t[1:]
    # Second pass — readings often restart with TODAY after the sign.
    if t.startswith("TODAY"):
        t = t[5:].strip()
        for _ in range(8):
            if len(t) == 0 or t[0] not in " ,.-:;":
                break
            t = t[1:]
    return t


def first_sentence(text):
    # Complete opening sentence only — keep the period so it never feels cut off.
    t = text.strip()
    best = -1
    for ch in [".", "!", "?"]:
        i = t.find(ch)
        if i >= 0 and (best < 0 or i < best):
            best = i
    if best >= 0:
        return t[0:best + 1].strip()
    return t


def wrap(c, text, maxw, font):
    words = []
    for w in text.split(" "):
        for _ in range(12):
            if c.text_width(w, font) <= maxw:
                break
            n = 1
            for k in range(1, len(w)):
                if c.text_width(w[0:k], font) > maxw:
                    break
                n = k
            words.append(w[0:n])
            w = w[n:]
        if w:
            words.append(w)

    lines = []
    cur = ""
    for w in words:
        trial = cur + " " + w if cur else w
        if c.text_width(trial, font) <= maxw:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def fits_panel(n_lines, font, lh):
    # Reject layouts whose last glyph row would draw past PANEL_BOTTOM.
    if n_lines < 1 or n_lines > MAX_LINES:
        return False
    h = FONT_H.get(font, 7)
    bottom = BODY_Y + (n_lines - 1) * lh + h - 1
    return bottom <= PANEL_BOTTOM


def try_fit(c, text, maxw):
    for t in TIERS:
        font = t[0]
        lh = t[1]
        cand = wrap(c, text, maxw, font)
        if len(cand) <= MAX_LINES and fits_panel(len(cand), font, lh):
            return [font, lh, cand]
    return None


def punchline(c, text, name, maxw):
    body = tighten(text, name)
    if body == "":
        body = str(text).upper().strip()
    hook = first_sentence(body)

    # 1) Full first sentence if it fits on-panel.
    hit = try_fit(c, hook, maxw)
    if hit != None:
        return hit

    # 2) Lead clause + period — still a finished thought, not a cliffhanger.
    comma = hook.find(",")
    if comma >= 12:
        short = hook[0:comma].strip() + "."
        hit = try_fit(c, short, maxw)
        if hit != None:
            return hit

    # 3) Last resort: as many whole words as fit, then a period.
    words = hook.replace(".", "").replace("!", "").replace("?", "").split(" ")
    for n in range(len(words), 3, -1):
        trial = " ".join(words[0:n]) + "."
        hit = try_fit(c, trial, maxw)
        if hit != None:
            return hit

    # Extreme fallback: densest font, max lines that still clear the frame.
    font = TIERS[len(TIERS) - 1][0]
    lh = TIERS[len(TIERS) - 1][1]
    lines = wrap(c, hook, maxw, font)
    for _ in range(8):
        if len(lines) <= 1 or fits_panel(len(lines), font, lh):
            break
        lines = lines[0:len(lines) - 1]
    if len(lines) > MAX_LINES:
        lines = lines[0:MAX_LINES]
    return [font, lh, lines]


def fetch_daily(sign_id):
    r = http.get(
        API_URL,
        headers = {
            "User-Agent": "(glance-horoscope, reyos86@github)",
            "Accept": "application/json",
        },
        params = {"sign": sign_id},
        ttl_seconds = 21600,
    )

    if r["status_code"] != 200:
        return {"ok": False, "title": "HOROSCOPE", "sub": "UNAVAILABLE"}

    j = r["json"]
    if j == None:
        return {"ok": False, "title": "HOROSCOPE", "sub": "UNAVAILABLE"}

    data = j.get("data", {})
    if data == None:
        data = {}

    text = data.get("horoscope", "")
    if text == None or str(text).strip() == "":
        return {"ok": False, "title": "HOROSCOPE", "sub": "NO DATA"}

    return {"ok": True, "text": str(text).upper()}


def draw_mark(c, sign_id, color):
    # Top-left glyph tile (22x22 art + 1px pad inside accent frame).
    c.rect(0, 0, 24, 23, fill = "#050508", outline = color)
    x = 1
    y = 1
    if sign_id == "aries":
        c.image("aries.png", x, y, w = 22, h = 22)
    elif sign_id == "taurus":
        c.image("taurus.png", x, y, w = 22, h = 22)
    elif sign_id == "gemini":
        c.image("gemini.png", x, y, w = 22, h = 22)
    elif sign_id == "cancer":
        c.image("cancer.png", x, y, w = 22, h = 22)
    elif sign_id == "leo":
        c.image("leo.png", x, y, w = 22, h = 22)
    elif sign_id == "virgo":
        c.image("virgo.png", x, y, w = 22, h = 22)
    elif sign_id == "libra":
        c.image("libra.png", x, y, w = 22, h = 22)
    elif sign_id == "scorpio":
        c.image("scorpio.png", x, y, w = 22, h = 22)
    elif sign_id == "sagittarius":
        c.image("sagittarius.png", x, y, w = 22, h = 22)
    elif sign_id == "capricorn":
        c.image("capricorn.png", x, y, w = 22, h = 22)
    elif sign_id == "aquarius":
        c.image("aquarius.png", x, y, w = 22, h = 22)
    else:
        c.image("pisces.png", x, y, w = 22, h = 22)


def draw_error(c, name, color, title, sub):
    c.fill("black")
    c.text(name, 2, 1, font = "6x8", color = color)
    c.text("TODAY", c.width - 2, 2, font = "4x5", color = "#8B9BB0", align = "right")
    c.line(0, 8, c.width - 1, 8, "#2A3544")
    c.text(title, c.width // 2, 14, font = "6x8", color = "white", align = "center")
    c.text(sub, c.width // 2, 24, font = "5x7", color = "#FF6B7A", align = "center")


def main(c, ctx):
    sign_key = resolve_sign(safe_input(ctx, "zodiacsign", "aries"))
    meta = SIGNS[sign_key]
    name = meta[0]
    color = meta[1]
    sign_id = sign_key.lower()

    result = fetch_daily(sign_id)
    if not result["ok"]:
        draw_error(c, name, color, result["title"], result["sub"])
        return

    c.fill("black")
    draw_mark(c, sign_id, color)
    c.text(name, 27, 1, font = "6x8", color = "white")
    c.text("TODAY", c.width - 2, 2, font = "4x5", color = color, align = "right")
    c.line(27, 9, c.width - 1, 9, "#2A3544")

    fitted = punchline(c, result["text"], name, c.width - 29)
    font = fitted[0]
    lh = fitted[1]
    lines = fitted[2]

    y = BODY_Y
    for i in range(len(lines)):
        c.text(lines[i], 27, y, font = font, color = "#E8EEF7")
        y += lh
