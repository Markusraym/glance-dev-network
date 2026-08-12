# Steam Players — live player counts for a favorites list (192x32).
#
# Data:
#   Current players — Steam Web API GetNumberOfCurrentPlayers (no key).
#   Game name — Steam Store appdetails (basic), with short-name fallbacks.
#
# Favorites: comma-separated AppIDs or known short names. Pages g1–g4 show
# the first four entries. Glance flips pages ~every 3s, so each page is one game.
#
# Bitmap fonts are UPPERCASE ONLY.

PLAYERS_URL = "https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/"
STORE_URL = "https://store.steampowered.com/api/appdetails"

# Short labels users can type instead of raw AppIDs.
ALIASES = {
    "CS2": "730",
    "CSGO": "730",
    "COUNTERSTRIKE": "730",
    "COUNTERSTRIKE2": "730",
    "DOTA": "570",
    "DOTA2": "570",
    "TF2": "440",
    "TEAMFORTRESS": "440",
    "TEAMFORTRESS2": "440",
    "GTA5": "271590",
    "GTAV": "271590",
    "ELDEN": "1245620",
    "ELDENRING": "1245620",
    "RUST": "252490",
    "PUBG": "578080",
    "APEX": "1172470",
    "APEXLEGENDS": "1172470",
    "VALHEIM": "892970",
    "HELLDIVERS": "553850",
    "HELLDIVERS2": "553850",
    "BG3": "1086940",
    "BALDURSGATE": "1086940",
    "BALDURSGATE3": "1086940",
    "CYBERPUNK": "1091500",
    "WARFRAME": "230410",
    "DESTINY2": "1085660",
    "ROCKETLEAGUE": "252950",
    "SKYRIM": "489830",
    "STARDEW": "413150",
    "HADES": "1145360",
    "PALWORLD": "1623730",
}

# Offline / store-miss display names for popular AppIDs.
KNOWN_NAMES = {
    "730": "COUNTER-STRIKE 2",
    "570": "DOTA 2",
    "440": "TEAM FORTRESS 2",
    "271590": "GRAND THEFT AUTO V",
    "1245620": "ELDEN RING",
    "252490": "RUST",
    "578080": "PUBG",
    "1172470": "APEX LEGENDS",
    "892970": "VALHEIM",
    "553850": "HELLDIVERS 2",
    "1086940": "BALDUR'S GATE 3",
    "1091500": "CYBERPUNK 2077",
    "230410": "WARFRAME",
    "1085660": "DESTINY 2",
    "252950": "ROCKET LEAGUE",
    "489830": "SKYRIM",
    "413150": "STARDEW VALLEY",
    "1145360": "HADES",
    "1623730": "PALWORLD",
}

STEAM_BLUE = "#66C0F4"
STEAM_DIM = "#4B619B"
OK_GREEN = "#3DDC82"
WARN = "#FFB84D"
MUTED = "#8B9BB0"


def normalize_token(raw):
    t = str(raw).upper().strip()
    # Strip spaces / punctuation so "CS 2" / "elden-ring" still match aliases.
    cleaned = ""
    for i in range(len(t)):
        ch = t[i]
        if ch >= "A" and ch <= "Z":
            cleaned += ch
        elif ch >= "0" and ch <= "9":
            cleaned += ch
    return cleaned


def resolve_appid(token):
    raw = str(token).strip()
    if raw == "":
        return None
    # Pure numeric AppID.
    digits = True
    for i in range(len(raw)):
        ch = raw[i]
        if ch < "0" or ch > "9":
            digits = False
            break
    if digits:
        # Strip leading zeros but keep "0" invalid.
        n = raw
        for _ in range(8):
            if len(n) > 1 and n[0] == "0":
                n = n[1:]
            else:
                break
        if n == "" or n == "0":
            return None
        return n
    key = normalize_token(raw)
    if key in ALIASES:
        return ALIASES[key]
    return None


def parse_favorites(text):
    out = []
    seen = {}
    for part in str(text).split(","):
        appid = resolve_appid(part)
        if appid == None:
            continue
        if appid in seen:
            continue
        seen[appid] = True
        out.append(appid)
    return out


def favorites_list(ctx):
    # Missing key → seed defaults. Explicit empty string → empty list (settings tip).
    value = ctx.inputs.get("favorites", None)
    if value == None:
        value = "730,570,1245620,252490"
    return parse_favorites(value)


def format_count(n):
    # Compact LED-friendly counts.
    if n >= 1000000:
        whole = n // 1000000
        frac = (n % 1000000) // 100000
        if frac == 0:
            return str(whole) + "M"
        return str(whole) + "." + str(frac) + "M"
    if n >= 10000:
        return str(n // 1000) + "K"
    if n >= 1000:
        whole = n // 1000
        frac = (n % 1000) // 100
        if frac == 0:
            return str(whole) + "K"
        return str(whole) + "." + str(frac) + "K"
    return str(n)


def fetch_players(appid):
    r = http.get(
        PLAYERS_URL,
        headers = {
            "User-Agent": "(glance-steam-players, reyos86@github)",
            "Accept": "application/json",
        },
        params = {"appid": appid},
        ttl_seconds = 180,
    )
    if r["status_code"] != 200:
        return None
    j = r["json"]
    if j == None:
        return None
    resp = j.get("response", None)
    if resp == None:
        return None
    if resp.get("result", 0) != 1:
        return None
    count = resp.get("player_count", None)
    if count == None:
        return None
    return int(count)


def fetch_store_name(appid):
    r = http.get(
        STORE_URL,
        headers = {
            "User-Agent": "(glance-steam-players, reyos86@github)",
            "Accept": "application/json",
        },
        params = {"appids": appid, "filters": "basic"},
        ttl_seconds = 86400,
    )
    if r["status_code"] != 200:
        return None
    j = r["json"]
    if j == None:
        return None
    entry = j.get(appid, None)
    if entry == None:
        return None
    if entry.get("success", False) != True:
        return None
    data = entry.get("data", None)
    if data == None:
        return None
    name = data.get("name", None)
    if name == None or str(name).strip() == "":
        return None
    return str(name).upper()


def game_name(appid):
    if appid in KNOWN_NAMES:
        # Prefer live store name when available; known label is a fast fallback.
        live = fetch_store_name(appid)
        if live != None:
            return live
        return KNOWN_NAMES[appid]
    live = fetch_store_name(appid)
    if live != None:
        return live
    return "APP " + appid


def fit_name(c, name, maxw):
    t = str(name).upper().strip()
    for font in ["6x8", "5x7", "4x5"]:
        if c.text_width(t, font) <= maxw:
            return [font, t]
    # Truncate on word boundaries when possible.
    words = t.split(" ")
    for font in ["5x7", "4x5"]:
        cur = ""
        for w in words:
            trial = cur + " " + w if cur else w
            if c.text_width(trial, font) <= maxw:
                cur = trial
            else:
                break
        if cur != "":
            return [font, cur]
    # Hard clip characters.
    font = "4x5"
    out = ""
    for i in range(len(t)):
        trial = out + t[i]
        if c.text_width(trial, font) > maxw:
            break
        out = trial
    return [font, out]


def draw_chrome(c, slot, total):
    c.fill("#0B141C")
    c.text("STEAM", 2, 1, font = "5x7", color = STEAM_BLUE)
    if total > 0 and slot < total:
        tag = "#" + str(slot + 1) + "/" + str(total)
        c.text(tag, c.width - 2, 2, font = "4x5", color = STEAM_DIM, align = "right")
    c.line(0, 9, c.width - 1, 9, "#1B2838")


def draw_empty(c, reason):
    draw_chrome(c, 0, 0)
    c.text("FAVORITES", 2, 13, font = "5x7", color = "white")
    c.text(reason, 2, 23, font = "4x5", color = MUTED)


def draw_game(c, ctx, index):
    favorites = favorites_list(ctx)
    total = len(favorites)

    if total == 0:
        draw_empty(c, "ADD APPIDS IN SETTINGS")
        return

    if index >= total:
        # Extra pages when the list is shorter than 4 — tip, not a crash.
        draw_chrome(c, index, total)
        c.text("SLOT EMPTY", 2, 13, font = "5x7", color = MUTED)
        c.text("ADD MORE APPIDS", 2, 23, font = "4x5", color = STEAM_DIM)
        return

    appid = favorites[index]
    name = game_name(appid)
    count = fetch_players(appid)

    draw_chrome(c, index, total)
    fitted = fit_name(c, name, c.width - 4)
    c.text(fitted[1], 2, 12, font = fitted[0], color = "white")

    if count == None:
        c.text("PLAYERS UNAVAILABLE", 2, 23, font = "4x5", color = WARN)
        return

    label = format_count(count) + " PLAYING"
    c.text(label, 2, 23, font = "5x7", color = OK_GREEN)
    id_label = "ID " + appid
    # Only show AppID when it won't collide with the count.
    if c.text_width(label, "5x7") + 6 + c.text_width(id_label, "4x5") <= c.width:
        c.text(id_label, c.width - 2, 24, font = "4x5", color = STEAM_DIM, align = "right")


def g1(c, ctx):
    draw_game(c, ctx, 0)


def g2(c, ctx):
    draw_game(c, ctx, 1)


def g3(c, ctx):
    draw_game(c, ctx, 2)


def g4(c, ctx):
    draw_game(c, ctx, 3)
