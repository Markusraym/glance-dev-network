# Tempest Weather (128x32)
#
# Live conditions from the user's own WeatherFlow Tempest station, via
# WeatherFlow's free-for-owners REST API (swd.weatherflow.com). Requires a
# personal access token from tempestwx.com > Settings > Data Authorizations.
#
# VERIFICATION NOTE: swd.weatherflow.com's endpoints and auth behavior (401
# without a token) were confirmed live. The success-response field names below
# (obs.*, current_conditions.*, forecast.daily[].*, timezone_offset_minutes)
# are based on WeatherFlow's published API docs, NOT verified against a live
# token/station - I didn't have one to test with. If a page shows "N/A" or
# blank values that a working station should have, the most likely cause is a
# field name mismatch here; check the actual JSON from a real request and
# adjust the .get(...) calls below.

CARDINAL_NAMES = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
WEEKDAY_NAMES = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

SUN_BITMAP = [
    [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
    [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
    [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
    [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
    [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
]

CLOUD_BITMAP = [
    [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
    [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
    [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
]

MINI_SUN_BITMAP = [
    [0, 0, 1, 1, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 1, 1, 0, 0],
]

MINI_CLOUD_BITMAP = [
    [0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
]

# ---------- small input helper ----------
# An unset/cleared input can come back as None even with a fallback given to
# ctx.inputs.get(), so coerce before using it (see apps/local-aqi, apps/stocks, etc).

def _s(ctx, key, fallback):
    v = ctx.inputs.get(key, fallback)
    if v == None:
        return fallback
    return v

# ---------- pure-math / formatting helpers (no round(), no while) ----------

def compass_index(deg):
    return int((deg + 11.25) // 22.5) % 16

def round_int(x):
    if x >= 0:
        return int(x + 0.5)
    else:
        return int(x - 0.5)

def pad_int(n, width):
    s = str(n)
    sign = ""
    if s[0] == "-":
        sign = "-"
        s = s[1:]
    for i in range(width):
        if len(s) >= width:
            break
        s = "0" + s
    return sign + s

def format1(value):
    neg = value < 0
    v = -value if neg else value
    tenths = round_int(v * 10)
    whole = tenths // 10
    frac = tenths % 10
    s = str(whole) + "." + str(frac)
    if neg and (whole != 0 or frac != 0):
        s = "-" + s
    return s

def format2(value):
    cents = round_int(value * 100)
    whole = cents // 100
    frac = cents % 100
    return str(whole) + "." + pad_int(frac, 2)

def format3(value):
    thousandths = round_int(value * 1000)
    whole = thousandths // 1000
    frac = thousandths % 1000
    return str(whole) + "." + pad_int(frac, 3)

def format4(value):
    # Used for signed lat/lon - unlike format2/format3, must not rely on
    # floor-division of a negative int (e.g. -751234 // 10000 == -76, not
    # -75), so it strips the sign first like format1 does.
    neg = value < 0
    v = -value if neg else value
    tenthousandths = round_int(v * 10000)
    whole = tenthousandths // 10000
    frac = tenthousandths % 10000
    s = str(whole) + "." + pad_int(frac, 4)
    if neg and (whole != 0 or frac != 0):
        s = "-" + s
    return s

def c_to_f(celsius):
    return celsius * 1.8 + 32.0

def mm_to_in(mm):
    return mm / 25.4

def date_from_iso(iso_time):
    return (int(iso_time[0:4]), int(iso_time[5:7]), int(iso_time[8:10]))

def days_from_civil(y, m, d):
    # Howard Hinnant's civil-date -> days-since-epoch (1970-01-01).
    yy = (y - 1) if m <= 2 else y
    era = (yy // 400) if yy >= 0 else ((yy - 399) // 400)
    yoe = yy - era * 400
    mm = (m + 9) if m <= 2 else (m - 3)
    doy = (153 * mm + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468

def fit_font(c, text, options, maxw):
    # Picks the largest font that fits, so a wide value (e.g. a negative or
    # 3-digit temp) never runs into a neighboring fixed-position element.
    for f in options:
        if c.text_width(text, f) <= maxw:
            return f
    return options[len(options) - 1]

def epoch_to_local_hhmm(epoch, tz_offset_min):
    local_epoch = epoch + tz_offset_min * 60
    secs_of_day = local_epoch % 86400
    hour24 = secs_of_day // 3600
    minute = (secs_of_day % 3600) // 60
    ampm = "AM" if hour24 < 12 else "PM"
    hour12 = hour24 % 12
    if hour12 == 0:
        hour12 = 12
    return str(hour12) + ":" + pad_int(minute, 2) + " " + ampm

def tempest_icon_to_cond(icon):
    if icon == None:
        return "Clouds"
    if "thunderstorm" in icon:
        return "Thunderstorm"
    if "sleet" in icon:
        return "Sleet"
    if "snow" in icon:
        return "Snow"
    if "rain" in icon:
        return "Rain"
    if "fog" in icon:
        return "Fog"
    if "windy" in icon:
        return "Windy"
    if "partly-cloudy" in icon:
        if "night" in icon:
            return "PartlyCloudyNight"
        return "PartlyCloudy"
    if "clear" in icon:
        if "night" in icon:
            return "ClearNight"
        return "Clear"
    return "Clouds"

def nws_to_cond(short_forecast):
    # NWS forecast periods carry no icon field worth parsing (it's a URL
    # image path, not a stable vocabulary) - shortForecast text like "Chance
    # Rain Showers" or "Mostly Sunny" is the reliable classifier instead.
    s = short_forecast.lower()
    if "thunderstorm" in s:
        return "Thunderstorm"
    elif "snow" in s or "flurries" in s:
        return "Snow"
    elif "sleet" in s or "freezing" in s or "ice" in s:
        return "Sleet"
    elif "rain" in s or "shower" in s or "drizzle" in s:
        return "Rain"
    elif "fog" in s or "haze" in s:
        return "Fog"
    elif "wind" in s:
        return "Windy"
    elif "sunny" in s or "clear" in s:
        return "Clear"
    elif "partly" in s or "mostly sunny" in s or "mostly clear" in s:
        return "PartlyCloudy"
    elif "cloud" in s or "overcast" in s:
        return "Clouds"
    else:
        return "Clouds"

# ---------- network ----------

def fetch_stations(token):
    return http.get(
        "https://swd.weatherflow.com/swd/rest/stations",
        params = {"token": token},
        ttl_seconds = 3600,
    )

def fetch_observation(token, station_id):
    # units_temp is deliberately omitted: WeatherFlow rounds its own C->F
    # conversion to whole degrees, throwing away the decimal precision we
    # want. Native units_temp (Celsius) keeps full precision - see c_to_f().
    # units_precip is also omitted: every precip_accum_* field this app reads
    # ignores it and always comes back in native mm - confirmed live for
    # today, yesterday, and last-hour totals. Converted client-side instead,
    # see mm_to_in().
    return http.get(
        "https://swd.weatherflow.com/swd/rest/observations/station/" + str(station_id),
        params = {
            "token": token,
            "units_wind": "mph",
            "units_pressure": "inhg",
            "units_distance": "mi",
        },
        ttl_seconds = 120,
    )

def fetch_better_forecast(token, station_id):
    # units_temp omitted for the same reason as fetch_observation() above.
    # units_precip omitted too, though not currently proven for this specific
    # endpoint - no precip field is read from better_forecast today, so this
    # is just staying consistent/honest rather than a confirmed fix here.
    return http.get(
        "https://swd.weatherflow.com/swd/rest/better_forecast",
        params = {
            "station_id": str(station_id),
            "token": token,
            "units_wind": "mph",
            "units_pressure": "inhg",
        },
        ttl_seconds = 300,
    )

def fetch_nws_points(lat, lon):
    return http.get(
        "https://api.weather.gov/points/" + format4(lat) + "," + format4(lon),
        headers = {"User-Agent": "GDN-Tempest-Weather (glance-led-panel)", "Accept": "application/geo+json"},
        ttl_seconds = 2592000,
    )

def fetch_nws_forecast(url):
    return http.get(
        url,
        headers = {"User-Agent": "GDN-Tempest-Weather (glance-led-panel)", "Accept": "application/geo+json"},
        ttl_seconds = 3600,
    )

def resolve_station(ctx):
    token = _s(ctx, "token", "")
    if not token:
        return None, "no token"

    resp = fetch_stations(token)
    if resp["status_code"] != 200:
        return None, "auth failed"

    stations = resp["json"].get("stations", [])
    if len(stations) == 0:
        return None, "no stations"

    chosen = stations[0]

    return {
        "token": token,
        "station_id": chosen.get("station_id"),
        "name": chosen.get("public_name", None) or chosen.get("name", "STATION"),
        "lat": chosen.get("latitude", 0),
        "lon": chosen.get("longitude", 0),
        "tz_offset_min": chosen.get("timezone_offset_minutes", 0),
    }, None

# ---------- drawing helpers ----------

def draw_header(c, name, time_str):
    c.text(name.upper(), 2, 1, font = "4x5", color = "white", align = "left")
    c.text(time_str.upper(), 126, 1, font = "4x5", color = "white", align = "right")
    c.line(0, 7, 127, 7, "#333333")

def draw_sun(c, x, y):
    c.bitmap(SUN_BITMAP, x, y, "amber")
    cx = x + 7
    cy = y + 7
    c.line(cx, cy - 9, cx, cy - 7, "amber")
    c.line(cx, cy + 7, cx, cy + 9, "amber")
    c.line(cx - 9, cy, cx - 7, cy, "amber")
    c.line(cx + 7, cy, cx + 9, cy, "amber")
    c.line(cx - 7, cy - 7, cx - 5, cy - 5, "amber")
    c.line(cx + 5, cy - 5, cx + 7, cy - 7, "amber")
    c.line(cx - 7, cy + 7, cx - 5, cy + 5, "amber")
    c.line(cx + 5, cy + 5, cx + 7, cy + 7, "amber")

def draw_cloud(c, x, y, color):
    c.bitmap(CLOUD_BITMAP, x, y, color)

def draw_partly_cloudy(c, x, y):
    c.bitmap(SUN_BITMAP, x + 6, y - 2, "amber")
    draw_cloud(c, x, y + 5, "#AAAAAA")

def draw_moon(c, x, y):
    cx = x + 7
    cy = y + 5
    c.fill_circle(cx, cy, 7, "#DDDDDD")
    c.fill_circle(cx - 3, cy - 2, 7, "#000000")

def draw_partly_cloudy_night(c, x, y):
    draw_moon(c, x + 6, y - 2)
    draw_cloud(c, x, y + 5, "#AAAAAA")

def draw_rain(c, x, y):
    c.line(x + 4, y + 10, x + 3, y + 14, "#3399FF")
    c.line(x + 9, y + 10, x + 8, y + 14, "#3399FF")
    c.line(x + 14, y + 10, x + 13, y + 14, "#3399FF")

def draw_snow(c, x, y):
    c.pixel(x + 4, y + 11, "white")
    c.pixel(x + 9, y + 12, "white")
    c.pixel(x + 14, y + 11, "white")
    c.pixel(x + 6, y + 14, "white")
    c.pixel(x + 11, y + 14, "white")

def draw_sleet(c, x, y):
    draw_cloud(c, x, y, "#999999")
    c.line(x + 4, y + 10, x + 3, y + 13, "#3399FF")
    c.pixel(x + 9, y + 12, "white")
    c.line(x + 14, y + 10, x + 13, y + 13, "#3399FF")

def draw_bolt(c, x, y):
    c.line(x + 11, y + 9, x + 8, y + 15, "amber")
    c.line(x + 8, y + 15, x + 12, y + 15, "amber")
    c.line(x + 12, y + 15, x + 9, y + 21, "amber")

def draw_fog(c, x, y):
    draw_cloud(c, x, y, "#999999")
    c.line(x + 2, y + 10, x + 17, y + 10, "#CCCCCC")
    c.line(x, y + 12, x + 19, y + 12, "#CCCCCC")

def draw_windy(c, x, y):
    c.line(x + 2, y + 6, x + 14, y + 6, "#AAAAAA")
    c.line(x + 14, y + 6, x + 16, y + 4, "#AAAAAA")
    c.line(x, y + 10, x + 12, y + 10, "#AAAAAA")
    c.line(x + 12, y + 10, x + 14, y + 12, "#AAAAAA")
    c.line(x + 4, y + 14, x + 16, y + 14, "#AAAAAA")

def draw_arrow_up(c, x, y, color):
    c.line(x + 2, y, x + 2, y + 4, color)
    c.line(x, y + 2, x + 2, y, color)
    c.line(x + 4, y + 2, x + 2, y, color)

def draw_arrow_down(c, x, y, color):
    c.line(x + 2, y, x + 2, y + 4, color)
    c.line(x, y + 2, x + 2, y + 4, color)
    c.line(x + 4, y + 2, x + 2, y + 4, color)

def draw_arrow_flat(c, x, y, color):
    c.line(x, y + 2, x + 4, y + 2, color)

def draw_icon(c, cond, x, y):
    if cond == "Clear":
        draw_sun(c, x, y)
    elif cond == "ClearNight":
        draw_moon(c, x, y)
    elif cond == "PartlyCloudy":
        draw_partly_cloudy(c, x, y)
    elif cond == "PartlyCloudyNight":
        draw_partly_cloudy_night(c, x, y)
    elif cond == "Rain":
        draw_cloud(c, x, y, "#888888")
        draw_rain(c, x, y)
    elif cond == "Sleet":
        draw_sleet(c, x, y)
    elif cond == "Thunderstorm":
        draw_cloud(c, x, y, "#666666")
        draw_bolt(c, x, y)
    elif cond == "Snow":
        draw_cloud(c, x, y, "#AAAAAA")
        draw_snow(c, x, y)
    elif cond == "Fog":
        draw_fog(c, x, y)
    elif cond == "Windy":
        draw_windy(c, x, y)
    elif cond == "Clouds":
        draw_cloud(c, x, y, "#AAAAAA")
    else:
        draw_cloud(c, x, y, "#999999")


# (top, bottom) pixel extent of each big icon, relative to the y anchor passed
# to draw_icon - these shapes vary a lot in height (a plain cloud is 9px tall,
# a thunderstorm's bolt reaches 21px below its anchor), so centering the icon
# in its content band means each condition needs its own anchor offset.
def icon_vextent(cond):
    if cond == "Clear":
        return (-2, 16)
    elif cond == "ClearNight":
        return (-2, 12)
    elif cond == "PartlyCloudy":
        return (-2, 13)
    elif cond == "PartlyCloudyNight":
        return (-4, 13)
    elif cond == "Rain" or cond == "Snow":
        return (0, 14)
    elif cond == "Sleet":
        return (0, 13)
    elif cond == "Thunderstorm":
        return (0, 21)
    elif cond == "Fog":
        return (0, 12)
    elif cond == "Windy":
        return (4, 14)
    else:
        return (0, 8)

def centered_icon_y(cond, band_top, band_bottom):
    top, bottom = icon_vextent(cond)
    band_mid = (band_top + band_bottom) // 2
    return band_mid - (top + bottom) // 2

# Half-scale icon set for the 3-column forecast page - the full-size icons
# above (up to 20px wide, 21px tall for a thunderbolt) don't fit a ~42px
# column alongside a weekday label and hi/lo text.
def draw_mini_sun(c, x, y):
    c.bitmap(MINI_SUN_BITMAP, x, y, "amber")

def draw_mini_cloud(c, x, y, color):
    c.bitmap(MINI_CLOUD_BITMAP, x, y, color)

def draw_mini_partly_cloudy(c, x, y):
    c.bitmap(MINI_SUN_BITMAP, x + 4, y - 2, "amber")
    draw_mini_cloud(c, x, y + 3, "#AAAAAA")

def draw_mini_rain(c, x, y):
    c.line(x + 3, y + 6, x + 2, y + 8, "#3399FF")
    c.line(x + 8, y + 6, x + 7, y + 8, "#3399FF")

def draw_mini_snow(c, x, y):
    c.pixel(x + 3, y + 7, "white")
    c.pixel(x + 8, y + 7, "white")
    c.pixel(x + 5, y + 8, "white")

def draw_mini_sleet(c, x, y):
    draw_mini_cloud(c, x, y, "#999999")
    c.pixel(x + 3, y + 7, "#3399FF")
    c.pixel(x + 8, y + 7, "white")

def draw_mini_bolt(c, x, y):
    c.line(x + 7, y + 6, x + 5, y + 8, "amber")
    c.line(x + 5, y + 8, x + 8, y + 8, "amber")

def draw_mini_fog(c, x, y):
    draw_mini_cloud(c, x, y, "#999999")
    c.line(x + 1, y + 7, x + 10, y + 7, "#CCCCCC")

def draw_mini_windy(c, x, y):
    c.line(x + 1, y + 4, x + 9, y + 4, "#AAAAAA")
    c.line(x, y + 7, x + 8, y + 7, "#AAAAAA")

def draw_mini_icon(c, cond, x, y):
    if cond == "Clear" or cond == "ClearNight":
        draw_mini_sun(c, x + 1, y)
    elif cond == "PartlyCloudy" or cond == "PartlyCloudyNight":
        draw_mini_partly_cloudy(c, x, y)
    elif cond == "Rain":
        draw_mini_cloud(c, x, y, "#888888")
        draw_mini_rain(c, x, y)
    elif cond == "Sleet":
        draw_mini_sleet(c, x, y)
    elif cond == "Thunderstorm":
        draw_mini_cloud(c, x, y, "#666666")
        draw_mini_bolt(c, x, y)
    elif cond == "Snow":
        draw_mini_cloud(c, x, y, "#AAAAAA")
        draw_mini_snow(c, x, y)
    elif cond == "Fog":
        draw_mini_fog(c, x, y)
    elif cond == "Windy":
        draw_mini_windy(c, x, y)
    elif cond == "Clouds":
        draw_mini_cloud(c, x, y, "#AAAAAA")
    else:
        draw_mini_cloud(c, x, y, "#999999")

def rgb_to_hex(r, g, b):
    digits = "0123456789ABCDEF"
    r = 0 if r < 0 else (255 if r > 255 else r)
    g = 0 if g < 0 else (255 if g > 255 else g)
    b = 0 if b < 0 else (255 if b > 255 else b)
    return "#" + digits[r // 16] + digits[r % 16] + digits[g // 16] + digits[g % 16] + digits[b // 16] + digits[b % 16]

def lerp_color(v, vmax, low, high):
    t = (float(v) / float(vmax)) if vmax > 0 else 0.0
    if t < 0.0:
        t = 0.0
    if t > 1.0:
        t = 1.0
    r = round_int(low[0] + (high[0] - low[0]) * t)
    g = round_int(low[1] + (high[1] - low[1]) * t)
    b = round_int(low[2] + (high[2] - low[2]) * t)
    return rgb_to_hex(r, g, b)

# Fixed 5-tier band scales for the segmented meter (see draw_segment_gauge
# below). Each metric's colors are hand-picked rather than sampled off a
# continuous low->high lerp: a lerp anchored at a near-black "zero" made the
# bottom (already-lit) bands nearly indistinguishable from the dimmed,
# not-yet-reached ones at low readings - confirmed by rendering solar=40 and
# brightness=300, both of which looked almost entirely dark. Fixed, clearly
# saturated colors per tier avoid that regardless of how low the reading is.

# Standard EPA UV Index scale (Low/Moderate/High/Very High/Extreme) - these
# specific 5 colors are the widely recognized ones for UV specifically.
UV_BAND_LOWS = [0.0, 3.0, 6.0, 8.0, 11.0]
UV_BAND_COLORS = ["#00A000", "#DCC800", "#FF8800", "#DC0000", "#8833CC"]

SOLAR_BAND_LOWS = [0.0, 280.0, 560.0, 840.0, 1120.0]
SOLAR_BAND_COLORS = ["#663300", "#996600", "#CC9900", "#FFCC00", "#FFEE66"]

BRIGHT_BAND_LOWS = [0.0, 2000.0, 4000.0, 6000.0, 8000.0]
BRIGHT_BAND_COLORS = ["#334455", "#667788", "#99AABB", "#CCDDEE", "#FFFFFF"]

def hex_to_rgb(hexcolor):
    return (int(hexcolor[1:3], 16), int(hexcolor[3:5], 16), int(hexcolor[5:7], 16))

def dim_hex(hexcolor, factor):
    r, g, b = hex_to_rgb(hexcolor)
    return rgb_to_hex(round_int(r * factor), round_int(g * factor), round_int(b * factor))

# Multi-color segmented meter, like a hardware LED bargraph: 5 stacked bands,
# each keeping its OWN band color when lit (not recolored to match the
# current value), dimmed to ~15% brightness when not yet reached. Replaces
# the single-flat-color fill this page used to have.
def draw_segment_gauge(c, label, value_str, band_lows, band_colors, value, x0, x1):
    cx = (x0 + x1) // 2
    c.text(label.upper(), cx, 9, font = "4x5", color = "white", align = "center")

    n = len(band_lows)
    bar_top = 15
    bar_bottom = 25
    seg_h = (bar_bottom - bar_top) // n

    lit_count = 0
    for low in band_lows:
        if value >= low:
            lit_count += 1

    for i in range(n):
        seg_top = bar_bottom - (i + 1) * seg_h
        seg_bottom = bar_bottom - i * seg_h - 1
        color = band_colors[i] if i < lit_count else dim_hex(band_colors[i], 0.15)
        c.rect(x0, seg_top, x1, seg_bottom, fill = color)

    value_color = band_colors[lit_count - 1] if lit_count > 0 else "#888888"
    c.text(value_str.upper(), cx, 26, font = "4x5", color = value_color, align = "center")

def draw_error(c, msg):
    c.fill("#000000")
    c.text(msg.upper(), 4, 12, font = "5x7", color = "red", align = "left")

def temp_color(f):
    if f < 20:
        return "#0033FF"
    elif f < 32:
        return "#0066FF"
    elif f < 45:
        return "#00AAFF"
    elif f < 55:
        return "#00CCCC"
    elif f < 65:
        return "#33CC66"
    elif f < 75:
        return "amber"
    elif f < 85:
        return "#FF8800"
    elif f < 95:
        return "#FF4400"
    else:
        return "#FF0000"

def humidity_color(h):
    if h < 20:
        return "#0033FF"
    elif h < 35:
        return "#0066FF"
    elif h < 50:
        return "#00AAFF"
    elif h < 60:
        return "#00CCCC"
    elif h < 70:
        return "#33CC66"
    elif h < 80:
        return "amber"
    elif h < 90:
        return "#FF8800"
    elif h < 95:
        return "#FF4400"
    else:
        return "#FF0000"

# ---------- shared station load ----------

def load_station(c, ctx):
    station, err = resolve_station(ctx)
    if station == None:
        c.fill("#000000")
        if err == "no token":
            draw_error(c, "set api token")
        elif err == "station not found":
            draw_error(c, "station not found")
        elif err == "no stations":
            draw_error(c, "no stations found")
        else:
            draw_error(c, "auth failed")
        return None
    return station

# ---------- pages ----------

def current(c, ctx):
    station = load_station(c, ctx)
    if station == None:
        return

    fc_resp = fetch_better_forecast(station["token"], station["station_id"])
    if fc_resp["status_code"] != 200:
        draw_error(c, "station error")
        return

    cur = fc_resp["json"].get("current_conditions", {})
    obs_resp = fetch_observation(station["token"], station["station_id"])
    obs_list = obs_resp["json"].get("obs", []) if obs_resp["status_code"] == 200 else []
    ts = obs_list[0].get("timestamp", 0) if len(obs_list) > 0 else 0

    temp = c_to_f(cur.get("air_temperature", 0.0))
    temp_col = temp_color(temp)

    c.fill("#000000")
    time_str = epoch_to_local_hhmm(ts, station["tz_offset_min"])
    draw_header(c, station["name"], time_str)
    c.line(0, 8, 127, 8, temp_col)

    cond = tempest_icon_to_cond(cur.get("icon", None))
    icon_y = centered_icon_y(cond, 9, 31)
    draw_icon(c, cond, 4, icon_y)

    temp_str = format1(temp)
    temp_font = fit_font(c, temp_str, ["16x24", "10x16", "7x12"], 58)
    font_height = {"16x24": 24, "10x16": 16, "7x12": 12}[temp_font]
    temp_y = 9 + (24 - font_height) // 2
    c.text(temp_str, 38, temp_y, font = temp_font, color = temp_col, align = "left")

    unit_x = 38 + c.text_width(temp_str, temp_font) + 2
    c.text("F".upper(), unit_x, temp_y + 1, font = "5x7", color = temp_col, align = "left")

    feels_raw = cur.get("feels_like", None)
    feels = c_to_f(feels_raw) if feels_raw != None else temp
    feels_str = format1(feels) + "F"
    c.text("FEELS".upper(), 126, 9, font = "4x5", color = "#888888", align = "right")
    c.text("LIKE".upper(), 126, 15, font = "4x5", color = "#888888", align = "right")
    c.text(feels_str.upper(), 126, 22, font = "5x7", color = temp_color(feels), align = "right")

def conditions(c, ctx):
    station = load_station(c, ctx)
    if station == None:
        return

    fc_resp = fetch_better_forecast(station["token"], station["station_id"])
    if fc_resp["status_code"] != 200:
        draw_error(c, "station error")
        return

    cur = fc_resp["json"].get("current_conditions", {})
    obs_resp = fetch_observation(station["token"], station["station_id"])
    obs_list = obs_resp["json"].get("obs", []) if obs_resp["status_code"] == 200 else []
    ts = obs_list[0].get("timestamp", 0) if len(obs_list) > 0 else 0

    c.fill("#000000")
    time_str = epoch_to_local_hhmm(ts, station["tz_offset_min"])
    draw_header(c, station["name"], time_str)

    humidity = cur.get("relative_humidity", 0)
    pressure = cur.get("station_pressure", 0.0)
    dew_point = c_to_f(cur.get("dew_point", 0.0))

    c.text("HUMIDITY".upper(), 2, 11, font = "4x5", color = "white", align = "left")
    c.text((str(round_int(humidity)) + "%").upper(), 126, 11, font = "4x5", color = humidity_color(humidity), align = "right")

    pressure_str = (format2(pressure) + " IN").upper()
    c.text("PRESSURE".upper(), 2, 17, font = "4x5", color = "white", align = "left")
    c.text(pressure_str, 119, 17, font = "4x5", color = "white", align = "right")

    trend = cur.get("pressure_trend", None)
    if trend == "rising":
        draw_arrow_up(c, 122, 17, "white")
    elif trend == "falling":
        draw_arrow_down(c, 122, 17, "white")
    elif trend == "steady":
        draw_arrow_flat(c, 122, 17, "white")

    c.text("DEW POINT".upper(), 2, 23, font = "4x5", color = "white", align = "left")
    c.text((format1(dew_point) + "F").upper(), 126, 23, font = "4x5", color = temp_color(dew_point), align = "right")

def wind(c, ctx):
    station = load_station(c, ctx)
    if station == None:
        return

    fc_resp = fetch_better_forecast(station["token"], station["station_id"])
    if fc_resp["status_code"] != 200:
        draw_error(c, "station error")
        return

    cur = fc_resp["json"].get("current_conditions", {})
    obs_resp = fetch_observation(station["token"], station["station_id"])
    obs_list = obs_resp["json"].get("obs", []) if obs_resp["status_code"] == 200 else []
    ts = obs_list[0].get("timestamp", 0) if len(obs_list) > 0 else 0
    obs = obs_list[0] if len(obs_list) > 0 else {}

    c.fill("#000000")
    time_str = epoch_to_local_hhmm(ts, station["tz_offset_min"])
    draw_header(c, station["name"], time_str)

    speed = cur.get("wind_avg", 0.0)
    deg = cur.get("wind_direction", 0)
    gust = cur.get("wind_gust", None)
    idx = compass_index(deg)

    wind_val = CARDINAL_NAMES[idx] + " @ " + str(round_int(speed)) + " MPH"
    c.text("CURRENT WIND".upper(), 2, 11, font = "4x5", color = "white", align = "left")
    c.text(wind_val.upper(), 126, 11, font = "4x5", color = "white", align = "right")

    if gust != None:
        gust_val = str(round_int(gust)) + " MPH"
    else:
        gust_val = "N/A"
    c.text("GUSTING UP TO".upper(), 2, 17, font = "4x5", color = "white", align = "left")
    c.text(gust_val.upper(), 126, 17, font = "4x5", color = "white", align = "right")

    daily_high_gust = obs.get("wind_gust", None)
    if daily_high_gust != None:
        high_gust_val = str(round_int(daily_high_gust)) + " MPH"
    else:
        high_gust_val = "N/A"
    c.text("LATEST OBS GUST".upper(), 2, 23, font = "4x5", color = "white", align = "left")
    c.text(high_gust_val.upper(), 126, 23, font = "4x5", color = "#888888", align = "right")

def rainfall(c, ctx):
    station = load_station(c, ctx)
    if station == None:
        return

    obs_resp = fetch_observation(station["token"], station["station_id"])
    if obs_resp["status_code"] != 200:
        draw_error(c, "station error")
        return

    obs_list = obs_resp["json"].get("obs", [])
    if len(obs_list) == 0:
        draw_error(c, "no data")
        return
    obs = obs_list[0]

    c.fill("#000000")
    time_str = epoch_to_local_hhmm(obs.get("timestamp", 0), station["tz_offset_min"])
    draw_header(c, station["name"], time_str)

    # Every precip_accum_* field on this endpoint ignores units_precip=in and
    # comes back in native mm regardless - confirmed live for both today
    # (1.97 shown vs 0.08in actual, matching 1.97mm) and yesterday (2.26 vs
    # 0.08in, matching 2.26mm). Converting all three ourselves.
    today_total = mm_to_in(obs.get("precip_accum_local_day", 0.0))
    last_hour_raw = obs.get("precip_accum_last_1hr", None)
    yesterday_total = obs.get("precip_accum_local_yesterday", None)

    c.text("RAIN TODAY".upper(), 2, 11, font = "4x5", color = "white", align = "left")
    c.text((format3(today_total) + " IN").upper(), 126, 11, font = "4x5", color = "white", align = "right")

    last_hour_str = (format3(mm_to_in(last_hour_raw)) + " IN") if last_hour_raw != None else "N/A"
    c.text("RAIN LAST HOUR".upper(), 2, 17, font = "4x5", color = "white", align = "left")
    c.text(last_hour_str.upper(), 126, 17, font = "4x5", color = "white", align = "right")

    yesterday_str = (format3(mm_to_in(yesterday_total)) + " IN") if yesterday_total != None else "N/A"
    c.text("RAIN YESTERDAY".upper(), 2, 23, font = "4x5", color = "white", align = "left")
    c.text(yesterday_str.upper(), 126, 23, font = "4x5", color = "white", align = "right")

def uv(c, ctx):
    station = load_station(c, ctx)
    if station == None:
        return

    fc_resp = fetch_better_forecast(station["token"], station["station_id"])
    if fc_resp["status_code"] != 200:
        draw_error(c, "station error")
        return

    cur = fc_resp["json"].get("current_conditions", {})
    obs_resp = fetch_observation(station["token"], station["station_id"])
    obs_list = obs_resp["json"].get("obs", []) if obs_resp["status_code"] == 200 else []
    obs = obs_list[0] if len(obs_list) > 0 else {}
    ts = obs.get("timestamp", 0)

    c.fill("#000000")
    time_str = epoch_to_local_hhmm(ts, station["tz_offset_min"])
    draw_header(c, station["name"], time_str)

    # Prefer the raw observation's live sensor values over better_forecast's
    # current_conditions, which can lag/differ (confirmed for uv earlier).
    uv_val = obs.get("uv", None)
    if uv_val == None:
        uv_val = cur.get("uv", None)
    if uv_val == None:
        uv_val = 0.0

    solar = obs.get("solar_radiation", None)
    if solar == None:
        solar = cur.get("solar_radiation", None)
    if solar == None:
        solar = 0.0

    brightness = obs.get("brightness", None)
    if brightness == None:
        brightness = cur.get("brightness", None)
    if brightness == None:
        brightness = 0.0

    draw_segment_gauge(c, "UV", format2(uv_val), UV_BAND_LOWS, UV_BAND_COLORS, uv_val, 2, 42)
    draw_segment_gauge(c, "SOLAR", str(round_int(solar)), SOLAR_BAND_LOWS, SOLAR_BAND_COLORS, solar, 45, 85)
    draw_segment_gauge(c, "BRIGHT", str(round_int(brightness)), BRIGHT_BAND_LOWS, BRIGHT_BAND_COLORS, brightness, 88, 126)

def draw_forecast_unavailable(c):
    c.text("FORECAST".upper(), 64, 13, font = "4x5", color = "#888888", align = "center")
    c.text("UNAVAILABLE".upper(), 64, 19, font = "4x5", color = "#888888", align = "center")

def forecast(c, ctx):
    station = load_station(c, ctx)
    if station == None:
        return

    obs_resp = fetch_observation(station["token"], station["station_id"])
    obs_list = obs_resp["json"].get("obs", []) if obs_resp["status_code"] == 200 else []
    ts = obs_list[0].get("timestamp", 0) if len(obs_list) > 0 else 0

    c.fill("#000000")
    time_str = epoch_to_local_hhmm(ts, station["tz_offset_min"])
    draw_header(c, station["name"], time_str)

    # The forecast itself comes from the NWS (api.weather.gov), not
    # WeatherFlow - a station's own better_forecast is model-derived, while
    # the NWS forecast is the official human-issued one for the station's
    # location. Two calls: /points/{lat},{lon} resolves the station's
    # forecast office grid (cached a month, it never moves), then that
    # office's own /forecast URL returns the actual periods.
    points_resp = fetch_nws_points(station["lat"], station["lon"])
    if points_resp["status_code"] != 200:
        draw_forecast_unavailable(c)
        return

    forecast_url = points_resp["json"].get("properties", {}).get("forecast", None)
    if forecast_url == None:
        draw_forecast_unavailable(c)
        return

    fc_resp = fetch_nws_forecast(forecast_url)
    if fc_resp["status_code"] != 200:
        draw_forecast_unavailable(c)
        return

    periods = fc_resp["json"].get("properties", {}).get("periods", [])
    if len(periods) == 0:
        draw_forecast_unavailable(c)
        return

    today_y, today_m, today_d = date_from_iso(periods[0]["startTime"])
    today_days = days_from_civil(today_y, today_m, today_d)

    # NWS periods alternate day/night (e.g. "Wednesday" then "Wednesday
    # Night"), each covering one civil date - group by date so a day's high
    # (isDaytime) and low (the following night) land in the same entry.
    days_by_key = {}
    order = []
    for p in periods:
        y, m, d = date_from_iso(p["startTime"])
        key = days_from_civil(y, m, d)
        if key not in days_by_key:
            days_by_key[key] = {}
            order.append(key)
        if p.get("isDaytime", False):
            days_by_key[key]["hi"] = p.get("temperature", None)
            days_by_key[key]["short"] = p.get("shortForecast", "")
        else:
            days_by_key[key]["lo"] = p.get("temperature", None)
            if "short" not in days_by_key[key]:
                days_by_key[key]["short"] = p.get("shortForecast", "")

    col_w = 128 // 3
    count = 0
    for key in order:
        if key <= today_days:
            continue
        if count >= 3:
            break
        day = days_by_key[key]
        cx = count * col_w + col_w // 2
        count += 1

        weekday = (key + 4) % 7
        c.text(WEEKDAY_NAMES[weekday].upper(), cx, 8, font = "4x5", color = "white", align = "center")

        cond = nws_to_cond(day.get("short", ""))
        draw_mini_icon(c, cond, cx - 6, 14)

        hi = str(day["hi"]) if day.get("hi", None) != None else "--"
        lo = str(day["lo"]) if day.get("lo", None) != None else "--"
        c.text((hi + "/" + lo).upper(), cx, 24, font = "5x7", color = "white", align = "center")

def lightning2(c, ctx):
    station = load_station(c, ctx)
    if station == None:
        return

    obs_resp = fetch_observation(station["token"], station["station_id"])
    if obs_resp["status_code"] != 200:
        draw_error(c, "station error")
        return

    obs_list = obs_resp["json"].get("obs", [])
    if len(obs_list) == 0:
        draw_error(c, "no data")
        return
    obs = obs_list[0]

    c.fill("#000000")
    time_str = epoch_to_local_hhmm(obs.get("timestamp", 0), station["tz_offset_min"])
    draw_header(c, station["name"], time_str)

    last_epoch = obs.get("lightning_strike_last_epoch", None)
    if last_epoch != None:
        minutes_ago = (obs.get("timestamp", 0) - last_epoch) // 60
        if minutes_ago < 1:
            last_str = "JUST NOW"
        elif minutes_ago < 60:
            last_str = str(minutes_ago) + " MIN AGO"
        else:
            last_str = str(minutes_ago // 60) + " HR AGO"
    else:
        last_str = "NONE RECENT"
    last_color = "red" if last_str == "JUST NOW" else "#888888"
    c.text("LAST STRIKE".upper(), 2, 11, font = "4x5", color = "white", align = "left")
    c.text(last_str.upper(), 126, 11, font = "4x5", color = last_color, align = "right")

    distance = obs.get("lightning_strike_last_distance", None)
    if distance != None:
        # Tempest's lightning sensor's advertised max detection range is ~25mi.
        dist_color = lerp_color(distance, 25.0, (220, 0, 0), (255, 180, 0))
        dist_str = str(round_int(distance)) + " MI"
    else:
        dist_color = "#888888"
        dist_str = "N/A"
    c.text("STRIKE DISTANCE".upper(), 2, 17, font = "4x5", color = "white", align = "left")
    c.text(dist_str.upper(), 126, 17, font = "4x5", color = dist_color, align = "right")

def lightning(c, ctx):
    station = load_station(c, ctx)
    if station == None:
        return

    obs_resp = fetch_observation(station["token"], station["station_id"])
    if obs_resp["status_code"] != 200:
        draw_error(c, "station error")
        return

    obs_list = obs_resp["json"].get("obs", [])
    if len(obs_list) == 0:
        draw_error(c, "no data")
        return
    obs = obs_list[0]

    c.fill("#000000")
    time_str = epoch_to_local_hhmm(obs.get("timestamp", 0), station["tz_offset_min"])
    draw_header(c, station["name"], time_str)

    rain_minutes = obs.get("precip_minutes_local_day", None)
    strikes_1hr = obs.get("lightning_strike_count_last_1hr", None)
    strikes_3hr = obs.get("lightning_strike_count_last_3hr", None)

    if rain_minutes == None:
        rain_minutes_str = "N/A"
    elif rain_minutes > 59:
        rain_minutes_str = str(rain_minutes // 60) + " H " + str(rain_minutes % 60) + " M"
    else:
        rain_minutes_str = str(rain_minutes) + " M"
    c.text("RAIN DURATION TODAY".upper(), 2, 11, font = "4x5", color = "white", align = "left")
    c.text(rain_minutes_str.upper(), 126, 11, font = "4x5", color = "#3399FF", align = "right")

    strikes_1hr_str = str(strikes_1hr) if strikes_1hr != None else "N/A"
    c.text("STRIKES - LAST HOUR".upper(), 2, 17, font = "4x5", color = "white", align = "left")
    c.text(strikes_1hr_str.upper(), 126, 17, font = "4x5", color = "amber", align = "right")

    strikes_3hr_str = str(strikes_3hr) if strikes_3hr != None else "N/A"
    c.text("STRIKES - LAST 3 HRS".upper(), 2, 23, font = "4x5", color = "white", align = "left")
    c.text(strikes_3hr_str.upper(), 126, 23, font = "4x5", color = "amber", align = "right")
