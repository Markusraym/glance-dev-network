# SiriusXM Now Playing (128x32)
#
# What's currently playing on up to 5 SiriusXM channels, picked from a
# multi-select input. Data from xmplaylist.com (https://xmplaylist.com/docs),
# an unaffiliated third party that tracks SiriusXM's on-air rotation - no
# SiriusXM account or login required. Confirmed live: GET /api/station/{deeplink}
# returns recently-played tracks newest-first with no auth needed; results[0]
# was ~2.5 minutes old when tested, close enough to call "now playing".
#
# Five fixed pages (channel_1..channel_5), same pattern as apps/now-playing:
# the manifest's "channels" input is a native HTML multi-select, which can't
# have the same option picked twice - duplicates are impossible by
# construction, not by extra validation code. "Up to 5" is enforced here by
# just taking the first 5 entries; anything past that is silently ignored.
#
# NOTE: browsers return a multi-select's chosen options in DOCUMENT order (the
# order they appear in the dropdown list), not the order the user clicked
# them - so channel_1 is whichever selected channel sorts first by channel
# number among your picks, not necessarily the first one you picked.

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
    "154 - En Vivo": "envivo",
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

def parse_channels(ctx):
    raw = _s(ctx, "channels", "")
    if raw == "":
        return []
    parts = raw.split(",")
    seen = {}
    out = []
    for p in parts:
        entry = p.strip()
        if entry == "":
            continue
        # Falls back to treating the raw entry as the deeplink itself if it's
        # not a recognized "number - name" choice, so a bare deeplink (e.g.
        # from --input on the CLI) still works.
        deeplink = CHANNEL_DEEPLINKS.get(entry, entry.lower())
        if deeplink == "" or deeplink in seen:
            continue
        seen[deeplink] = True
        out.append(deeplink)
        if len(out) >= 5:
            break
    return out

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

def draw_header(c, channel):
    name = channel.get("name", "?")
    number = channel.get("number", "")
    c.text((str(number) + "-" + name).upper(), 2, 1, font = "4x5", color = "white", align = "left")
    c.line(0, 7, 127, 7, "#333333")

def draw_now_playing(c, channel, track):
    draw_header(c, channel)

    artists = ", ".join(track.get("artists", []))
    title = track.get("title", "?")

    c.text_wrapped(title.upper(), 2, 9, 124, font = "5x7", color = "amber", line_gap = 1, max_lines = 2)
    c.text_wrapped(artists.upper(), 2, 27, 124, font = "4x5", color = "#888888", max_lines = 1)

def _page(c, ctx, index):
    c.fill("#000000")
    channels = parse_channels(ctx)
    if index >= len(channels):
        draw_error(c, "no channel set")
        return

    resp = fetch_now_playing(channels[index])
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
    draw_now_playing(c, channel, latest.get("track", {}))

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
