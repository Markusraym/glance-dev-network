# SiriusXM Now Playing (128x32)
#
# What's currently playing on up to 5 SiriusXM channels, picked from a
# multi-select input. Data from xmplaylist.com (https://xmplaylist.com/docs),
# an unaffiliated third party that tracks SiriusXM's on-air rotation - no
# SiriusXM account or login required. Confirmed live: GET /api/station/{deeplink}
# returns recently-played tracks newest-first with no auth needed; results[0]
# was ~2.5 minutes old when tested, close enough to call "now playing".
#
# Five fixed pages (channel_1..channel_5), each backed by its own single-
# select "channelN" input rather than one shared multi-select. A multi-select
# picking all 5 at once sounds simpler, but browsers return its choices in
# DOCUMENT order (the order they appear in the dropdown), not click order -
# so swapping just one station out meant re-scanning a 164-entry list to find
# and re-check everything, with no guarantee it even landed back in the same
# slot. Five separate dropdowns cost more manifest boilerplate but make each
# slot's identity explicit and swapping a single station a one-field edit.

# ---------- small input helper ----------
# An unset/cleared input can come back as None even with a fallback given to
# ctx.inputs.get(), so coerce before using it (see apps/local-aqi, apps/stocks, etc).

def _s(ctx, key, fallback):
    v = ctx.inputs.get(key, fallback)
    if v == None:
        return fallback
    return v

# ---------- channel lookup ----------
# Manifest choices are plain "number - name" (no deeplink suffix, so the
# picker shows the full station title without truncation) - this maps each
# choice string back to the xmplaylist.com deeplink the API actually wants.
# Regenerated from GET https://xmplaylist.com/api/station.

CHANNEL_DEEPLINKS = {
    "2 - SiriusXM Hits 1": "siriusxmhits1",
    "3 - Unwell Music": "unwellmusic",
    "4 - Life with John Mayer": "lifewithjohnmayer",
    "5 - The Pulse": "thepulse",
    "6 - PopRocks": "poprocks",
    "7 - 70s on 7": "70son7",
    "8 - 80s on 8": "80son8",
    "9 - 90s on 9": "90son9",
    "10 - Pop2K": "pop2k",
    "11 - The 10s Spot": "the10sspot",
    "12 - The Kelly Clarkson Connection": "kellyclarksonconnection",
    "13 - Pitbull's Globalization": "pitbullsglobalization",
    "14 - The Bridge": "thebridge",
    "15 - Yacht Rock Radio": "yachtrockradio",
    "16 - The Blend": "theblend",
    "17 - The Coffee House": "thecoffeehouse",
    "18 - The Beatles Channel": "thebeatleschannel",
    "19 - Bob Marley's Tuff Gong": "bobmarleystuffgong",
    "20 - E Street Radio": "estreetradio",
    "21 - Underground Garage": "undergroundgarage",
    "22 - Pearl Jam Radio": "pearljamradio",
    "23 - Grateful Dead": "gratefuldead",
    "24 - Radio Margaritaville": "radiomargaritaville",
    "25 - Classic Rewind": "classicrewind",
    "26 - Classic Vinyl": "classicvinyl",
    "27 - Alt2K": "alt2k",
    "28 - The Spectrum": "thespectrum",
    "29 - Phish Radio": "phishradio",
    "30 - Dave Matthews Band Radio": "davematthewsbandradio",
    "31 - Tom Petty Radio": "tompettyradio",
    "32 - U2 X-Radio": "u2xradio",
    "33 - 1st Wave": "1stwave",
    "34 - Lithium": "lithium",
    "35 - SiriusXMU": "siriusxmu",
    "36 - Alt Nation": "altnation",
    "37 - Octane": "octane",
    "38 - Ozzy's Boneyard": "ozzysboneyard",
    "39 - Hair Nation": "hairnation",
    "40 - Liquid Metal": "liquidmetal",
    "41 - SiriusXM Turbo": "siriusxmturbo",
    "42 - Maximum Metallica": "maximummetallica",
    "43 - Rock The Bells Radio": "rockthebellsradio",
    "44 - Hip-Hop Nation": "hiphopnation",
    "45 - Shade 45": "shade45",
    "46 - The Heat": "theheat",
    "47 - Heart & Soul": "heartsoul",
    "48 - The Flow": "theflow",
    "49 - Flex2K": "flex2k",
    "50 - SiriusXM FLY": "siriusxmfly",
    "51 - The Groove": "thegroove",
    "52 - BPM": "bpm",
    "53 - Diplo's Revolution": "diplosrevolution",
    "54 - Studio 54 Radio": "studio54radio",
    "55 - SiriusXM Chill": "siriusxmchill",
    "56 - The Highway": "thehighway",
    "57 - Y2Kountry": "y2kountry",
    "58 - Prime Country": "primecountry",
    "59 - No Shoes Radio": "noshoesradio",
    "60 - Carrie's Country": "carriescountry",
    "61 - Willie's Roadhouse": "williesroadhouse",
    "62 - Outlaw Country": "outlawcountry",
    "63 - Chris Stapleton Radio": "chrisstapletonradio",
    "64 - Morgan Wallen Radio": "morganwallenradio",
    "65 - Bluegrass Junction": "bluegrassjunction",
    "66 - Symphony Hall": "symphonyhall",
    "67 - Real Jazz": "realjazz",
    "68 - Watercolors": "watercolors",
    "69 - On Broadway": "onbroadway",
    "70 - Siriusly Sinatra": "siriuslysinatra",
    "71 - 40s Junction": "40sjunction",
    "72 - 50s Gold": "50sgold",
    "73 - 60s Gold": "60sgold",
    "74 - Smokey's Soul Town": "smokeyssoultown",
    "75 - BB King's Bluesville": "bbkingsbluesville",
    "76 - Elvis Radio": "elvisradio",
    "77 - Kirk Franklin's Praise": "kirkfranklinspraise",
    "78 - The Message": "themessage",
    "79 - Message Worship": "messageworship",
    "93 - Netflix Is A Joke Radio": "netflixisajokeradio",
    "94 - Comedy Greats": "comedygreats",
    "95 - Comedy Central Radio": "comedycentralradio",
    "96 - Kevin Hart's LOL Radio": "kevinhartslolradio",
    "97 - Comedy Roundup": "comedyroundup",
    "98 - Pure Comedy": "purecomedy",
    "99 - Sebastian Maniscalco's Comedy Radio": "sebastianmaniscalcocmdy",
    "104 - Conan O'Brien Radio": "conanobrienradio",
    "133 - Disney Hits": "disneyhits",
    "134 - Kids Place": "kidsplace",
    "135 - KIDZ BOP Radio": "kidzbopradio",
    "136 - CoComelon & Friends": "cocomelonfriends",
    "140 - Holy Culture Radio": "holycultureradio",
    "149 - Escape": "escape",
    "150 - Bill Gaither's enLighten": "billgaithersenlighten",
    "152 - Caliente": "caliente",
    "153 - Águila": "aguila",
    "155 - Latin Vault": "latinvault",
    "163 - Attitude Franco": "attitudefranco",
    "164 - Mixtape: North": "mixtapenorth",
    "165 - The Indigiverse": "theindigiverse",
    "166 - Racines Musicales": "racinesmusicales",
    "168 - SiriusXM Comedy Club": "siriusxmcomedyclub",
    "171 - Top of the Country Radio": "topofthecountryradio",
    "173 - The Verge": "theverge",
    "174 - Influence Franco": "influencefranco",
    "300 - SiriusXM 300": "siriusxm300",
    "301 - Road Trip Radio": "roadtripradio",
    "302 - Andy Cohen's Kiki Lounge": "andycohenskikilounge",
    "305 - Mosaic": "mosaic",
    "308 - Deep Tracks": "deeptracks",
    "309 - Jam On 309": "jamon309",
    "312 - Bon Jovi Radio": "bonjoviradio",
    "314 - Green Day's Idiot Nation": "greendaysidiotnation",
    "315 - Red Hot Chili Peppers": "redhotchilipeppers",
    "330 - SiriusXM Silk 330": "siriusxmsilk330",
    "332 - Shaggy Boombastic Radio": "shaggyboombasticradio",
    "340 - Radio Monaco": "radiomonaco",
    "341 - Utopia": "utopia",
    "349 - Bakersfield Beat": "bakersfieldbeat",
    "350 - Red White & Booze": "redwhitebooze",
    "359 - North Americana": "northamericana",
    "362 - Grown Folk JAMZ": "grownfolkjamz",
    "510 - Little Miss Twain Radio": "littlemisstwainradio",
    "550 - Pop Top 500": "poptop500",
    "551 - 80s on 8 Top 500": "80son8top500",
    "552 - 90s on 9 Top 500": "90son9top500",
    "553 - Classic Rock Top 1000": "classicrocktop1000",
    "556 - Hip-Hop Chronicles": "hiphopchronicles",
    "558 - Country Top 1000": "countrytop1000",
    "560 - Billboard Top 500": "billboardtop500",
    "602 - Holiday Traditions": "holidaytraditions",
    "702 - Disney Jr. Radio": "disneyjrradio",
    "703 - Pandora Now": "pandoranow",
    "705 - SiriusXM K-Pop": "siriusxmkpop",
    "708 - SiriusXM Love": "siriusxmlove",
    "709 - SiriusXO": "siriusxo",
    "710 - The Loft": "theloft",
    "711 - Petty's Buried Treasure": "pettysburiedtreasure",
    "713 - RockBar": "rockbar",
    "715 - Classic Rock Party": "classicrockparty",
    "721 - Stevie's Coolest Songs": "steviescoolestsongs",
    "724 - SoundCloud Radio": "soundcloudradio",
    "735 - Steve Aoki's Remix Radio": "steveaokisremixradio",
    "736 - A State of Armin": "astateofarmin",
    "737 - Experts Only Radio": "expertsonlyradio",
    "738 - One World Radio": "oneworldradio",
    "739 - Savior Sunday Daily": "saviorsundaydaily",
    "740 - Outsiders Radio": "outsidersradio",
    "741 - The Village": "thevillage",
    "744 - Met Opera Radio": "metoperaradio",
    "745 - SiriusXM Pops": "siriusxmpops",
    "746 - Spa": "spa",
    "757 - The Tragically Hip Radio": "thetragicallyhipradio",
    "758 - Iceberg": "iceberg",
    "759 - Les Tubes Franco": "lestubesfranco",
    "760 - Chucho's Cuba & Beyond": "chuchoscubabeyond",
    "761 - Celia Cruz AZÚCAR!": "celiacruzazucar",
    "762 - Caricia": "caricia",
    "763 - Viva": "viva",
    "764 - Latidos": "latidos",
    "765 - Flow Nación": "flownacion",
    "766 - Luna": "luna",
    "767 - Rumbón": "rumbonmusic",
    "768 - La Kueva": "lakueva",
    "769 - SiriusXM Dhamaka": "siriusxmdhamaka",
}

# ---------- input parsing ----------

CHANNEL_INPUT_KEYS = ["channel1", "channel2", "channel3", "channel4", "channel5"]

def channel_deeplink_for_slot(ctx, index):
    entry = _s(ctx, CHANNEL_INPUT_KEYS[index], "(none)").strip()
    if entry == "" or entry == "(none)":
        return None
    # Falls back to treating the raw entry as the deeplink itself if it's
    # not a recognized "number - name" choice, so a bare deeplink (e.g.
    # from --input on the CLI) still works.
    deeplink = CHANNEL_DEEPLINKS.get(entry, entry.lower())
    if deeplink == "":
        return None
    return deeplink

# ---------- network ----------

def fetch_now_playing(deeplink):
    return http.get(
        "https://xmplaylist.com/api/station/" + deeplink,
        headers = {"User-Agent": "GDN-SXM-NowPlaying (glance-led-panel)"},
        ttl_seconds = 60,
    )

# ---------- drawing ----------

def draw_error(c, msg):
    c.fill("#000000")
    c.text(msg.upper(), 4, 12, font = "5x7", color = "red", align = "left")

# ---------- genre-colored header ----------
# The station lookup returns a "genres" list that was previously fetched and
# thrown away - a loose, vibe-based palette per genre (not anything from
# SiriusXM's own branding), same spirit as the decade colors in
# apps/billboard-anniversaries. Only the first listed genre is used.

GENRE_COLORS = {
    "rock": "#8B0000",
    "pop": "#FF1493",
    "country": "#8B5A2B",
    "hiphop": "#FF8C00",
    "world": "#008080",
    "jazz": "#4B0082",
    "canadian": "#A8DADC",
    "dance": "#DA70D6",
    "comedy": "#FFEB3B",
    "christian": "#87CEEB",
    "kids": "#32CD32",
    "holiday": "#1E7B34",
    "more": "#555555",
}
DEFAULT_HEADER_COLOR = "#333333"  # no genre listed

def genre_color(channel):
    genres = channel.get("genres", [])
    if len(genres) == 0:
        return DEFAULT_HEADER_COLOR
    return GENRE_COLORS.get(genres[0], DEFAULT_HEADER_COLOR)

def brightness(hex_color):
    r = int(hex_color[1:3], 16)
    g = int(hex_color[3:5], 16)
    b = int(hex_color[5:7], 16)
    return (r * 299 + g * 587 + b * 114) // 1000

def text_color_for(bg_hex):
    # Several genre colors (comedy's yellow, canadian's icy blue) are bright
    # enough that white text would read weak - same fix as
    # apps/mlb-playoff-picture's text_color_for.
    if brightness(bg_hex) > 150:
        return "black"
    return "white"

def fit_font(c, text, options, maxw):
    # First font in `options` that fits at full size; falls back to the last
    # (smallest) if none do - so most channel names stay at the normal "4x5"
    # size and only the handful of long ones (e.g. "Sebastian Maniscalco's
    # Comedy Radio") drop down.
    for f in options:
        if c.text_width(text, f) <= maxw:
            return f
    return options[len(options) - 1]

def fit_text(c, text, font, maxw):
    # Even the smallest font can't fit every channel name (some run 35+
    # chars) - truncate on actual pixel width as the last resort so the
    # header text can never run off the panel edge.
    if c.text_width(text, font) <= maxw:
        return text
    for i in range(len(text), 0, -1):
        candidate = text[:i] + "..."
        if c.text_width(candidate, font) <= maxw:
            return candidate
    return "..."

def draw_header(c, channel):
    name = channel.get("name", "?")
    number = channel.get("number", "")
    text = (str(number) + "-" + name).upper()
    maxw = 124
    font = fit_font(c, text, ["4x5", "picopixel"], maxw)
    bg = genre_color(channel)
    c.rect(0, 0, 127, 6, fill = bg)
    c.text(fit_text(c, text, font, maxw), 2, 1, font = font, color = text_color_for(bg), align = "left")
    c.line(0, 7, 127, 7, "#333333")

# ---------- "played N min ago" ----------
# xmplaylist timestamps are plain UTC ("...Z"), so unlike apps/weather-alerts
# there's no zone offset to undo - just the date/time fields themselves.

def days_from_civil(y, m, d):
    yy = (y - 1) if m <= 2 else y
    era = (yy // 400) if yy >= 0 else ((yy - 399) // 400)
    yoe = yy - era * 400
    mm = (m + 9) if m <= 2 else (m - 3)
    doy = (153 * mm + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468

def iso_to_epoch_seconds(iso_time):
    y = int(iso_time[0:4])
    mo = int(iso_time[5:7])
    d = int(iso_time[8:10])
    h = int(iso_time[11:13])
    mi = int(iso_time[14:16])
    s = int(iso_time[17:19])
    return days_from_civil(y, mo, d) * 86400 + h * 3600 + mi * 60 + s

def played_ago_label(iso_time, now_unix):
    if iso_time == None or iso_time == "":
        return ""
    age_seconds = now_unix - iso_to_epoch_seconds(iso_time)
    if age_seconds < 60:
        return "JUST NOW"
    minutes = age_seconds // 60
    if minutes == 1:
        return "1 MIN AGO"
    return str(minutes) + " MIN AGO"

def draw_now_playing(c, channel, track, played_at, now_unix):
    draw_header(c, channel)

    artists = ", ".join(track.get("artists", []))
    title = track.get("title", "?")

    lines = c.text_wrapped(title.upper(), 2, 9, 124, font = "5x7", color = "amber", line_gap = 1, max_lines = 2)

    # A 2-line title already fills the space down to the artist line; only a
    # 1-line title leaves the ~10px gap this row needs - the equalizer and
    # timestamp used to just sit unused in that gap otherwise.
    if lines == 1:
        draw_equalizer(c, 8, 20, "#555555")
        ago = played_ago_label(played_at, now_unix)
        if ago != "":
            c.text(ago, 124, 17, font = "picopixel", color = "#555555", align = "right")

    c.text_wrapped(artists.upper(), 2, 27, 124, font = "4x5", color = "#888888", max_lines = 1)

def _page(c, ctx, index):
    c.fill("#000000")
    deeplink = channel_deeplink_for_slot(ctx, index)
    if deeplink == None:
        draw_error(c, "no channel set")
        return

    resp = fetch_now_playing(deeplink)
    if resp["status_code"] == 404:
        draw_error(c, "channel not found")
        return
    if resp["status_code"] == 429:
        draw_error(c, "rate limited")
        return
    if resp["status_code"] != 200:
        draw_error(c, "data error")
        return

    data = resp["json"]
    channel = data.get("channel", {})
    results = data.get("results", [])
    if len(results) == 0:
        c.fill("#000000")
        draw_header(c, channel)
        c.text("NO DATA YET".upper(), 4, 16, font = "4x5", color = "gray", align = "left")
        return

    latest = results[0]
    draw_now_playing(c, channel, latest.get("track", {}), latest.get("timestamp"), ctx.now.unix)

# ---------- pages ----------

EQ_HEIGHTS = [1, 2, 3, 2, 3, 2, 1]

def draw_equalizer(c, cx, baseline_y, color):
    # A tiny soundwave/EQ strip, bars grow up from a shared baseline.
    bar_w = 2
    pitch = 3
    start_x = cx - (len(EQ_HEIGHTS) * pitch - 1) // 2
    x = start_x
    for h in EQ_HEIGHTS:
        c.rect(x, baseline_y - h + 1, x + bar_w - 1, baseline_y, fill = color)
        x += pitch

def draw_satellite(c, x, y, color):
    # ~13x7 icon: two solar panels flanking a small body, antenna angled
    # up-right - nods to "satellite radio" rather than generic music imagery.
    c.rect(x, y + 2, x + 3, y + 6, fill = color)
    c.rect(x + 5, y + 3, x + 7, y + 5, fill = color)
    c.rect(x + 9, y + 2, x + 12, y + 6, fill = color)
    c.line(x + 6, y + 3, x + 9, y, color)

def draw_earth(c, cx, cy, radius, ocean_color, land_color):
    # Center is off-canvas (below/left) so only a rounded corner of the globe
    # peeks into frame, like a planet curving into the bottom-left corner.
    # The landmass is placed by an absolute on-canvas point (not an offset
    # from center) since center itself is off-canvas - an offset small enough
    # to stay inside the ocean circle still lands off-canvas too.
    c.fill_circle(cx, cy, radius, ocean_color)
    c.fill_circle(6, 28, 2, land_color)

def draw_downlink(c, x, y, color):
    # A few short marks landing on Earth's edge, suggesting the satellite's
    # signal arriving - kept small and off to the side so it never crosses
    # the title text through the middle of the card.
    c.pixel(x, y, color)
    c.pixel(x + 2, y - 2, color)
    c.pixel(x + 4, y - 4, color)

def intro(c, ctx):
    # An original title card, not a reproduction of SiriusXM's actual
    # trademarked logo - just this app's own bitmap-font styling.
    c.clear()
    draw_earth(c, -2, 38, 14, "#1E5FA8", "#2E8B3D")
    draw_downlink(c, 12, 19, "#555555")
    draw_satellite(c, 112, 3, "#CCCCCC")
    c.text("SIRIUSXM".upper(), 64, 2, font = "10x16_bold", color = "amber", align = "center")
    draw_equalizer(c, 64, 22, "amber")
    c.text("NOW PLAYING".upper(), 64, 24, font = "4x7", color = "gray", align = "center")

def channel_1(c, ctx):
    _page(c, ctx, 0)

def channel_2(c, ctx):
    _page(c, ctx, 1)

def channel_3(c, ctx):
    _page(c, ctx, 2)

def channel_4(c, ctx):
    _page(c, ctx, 3)

def channel_5(c, ctx):
    _page(c, ctx, 4)
