MONTHS = [
    "",
    "JAN",
    "FEB",
    "MAR",
    "APR",
    "MAY",
    "JUN",
    "JUL",
    "AUG",
    "SEP",
    "OCT",
    "NOV",
    "DEC",
]


def _draw_message(c, line1, line2, color):
    c.fill("black")

    c.text(
        str(line1).upper(),
        32,
        7,
        font = "5x7",
        color = color,
        align = "center",
    )

    c.text(
        str(line2).upper(),
        32,
        18,
        font = "5x7",
        color = color,
        align = "center",
    )


def _is_leap_year(year):
    if year % 400 == 0:
        return True

    if year % 100 == 0:
        return False

    return year % 4 == 0


def _days_before_year(year):
    previous_year = year - 1

    return (
        previous_year * 365
        + previous_year // 4
        - previous_year // 100
        + previous_year // 400
    )


def _days_before_month(year, month):
    month_days = [
        0,
        0,
        31,
        59,
        90,
        120,
        151,
        181,
        212,
        243,
        273,
        304,
        334,
    ]

    total = month_days[month]

    if month > 2 and _is_leap_year(year):
        total = total + 1

    return total


def _date_number(year, month, day):
    return (
        _days_before_year(year)
        + _days_before_month(year, month)
        + day
    )

def _split_race_name(value, maximum):
    text = str(value).upper()
    words = text.split(" ")

    line1 = ""
    line2 = ""

    for word in words:
        if line2 != "":
            candidate = line2 + " " + word

            if len(candidate) <= maximum:
                line2 = candidate
            continue

        if line1 == "":
            line1 = word
            continue

        candidate = line1 + " " + word

        if len(candidate) <= maximum:
            line1 = candidate
        else:
            line2 = word

    if len(line1) > maximum:
        line1 = line1[0:maximum]

    if len(line2) > maximum:
        line2 = line2[0:maximum]

    return {
        "line1": line1,
        "line2": line2,
    }

def _parse_race_date(start_time):
    # Expected RunSignup format:
    # 9/12/2026 7:00
    # 09/12/2026 07:00

    if start_time == None:
        return None

    text = str(start_time)
    date_time_parts = text.split(" ")

    if len(date_time_parts) < 1:
        return None

    date_parts = date_time_parts[0].split("/")

    if len(date_parts) != 3:
        return None

    return {
        "month": int(date_parts[0]),
        "day": int(date_parts[1]),
        "year": int(date_parts[2]),
    }


def _parse_now_date(now_value):
    if now_value == None:
        return None

    return {
        "year": now_value.year,
        "month": now_value.month,
        "day": now_value.day,
    }


def _days_until(start_time, now_value):
    race_date = _parse_race_date(start_time)
    current_date = _parse_now_date(now_value)

    if race_date == None or current_date == None:
        return None

    race_number = _date_number(
        race_date["year"],
        race_date["month"],
        race_date["day"],
    )

    current_number = _date_number(
        current_date["year"],
        current_date["month"],
        current_date["day"],
    )

    return race_number - current_number


def _format_date(start_time):
    race_date = _parse_race_date(start_time)

    if race_date == None:
        return "DATE TBD"

    month = race_date["month"]
    day = race_date["day"]

    if month < 1 or month > 12:
        return "DATE TBD"

    return MONTHS[month] + " " + str(day)


def _short_text(value, maximum):
    text = str(value).upper()

    if len(text) <= maximum:
        return text

    return text[0:maximum]


def _get_races(ctx):
    worker_url = str(
        ctx.inputs.get("workerurl", "")
    )

    app_token = ctx.inputs.get(
        "apptoken",
        "",
    )

    if worker_url == "":
        return {
            "status": "NO URL",
            "races": [],
        }

    if app_token == "":
        return {
            "status": "NO TOKEN",
            "races": [],
        }

    response = http.get(
        worker_url,
        headers = {
            "X-App-Key": app_token,
            "Accept": "application/json",
        },
        ttl_seconds = 900,
    )

    if response["status_code"] != 200:
        return {
            "status": "HTTP " + str(
                response["status_code"]
            ),
            "races": [],
        }

    data = response["json"]

    if data == None:
        return {
            "status": "NO JSON",
            "races": [],
        }

    if data.get("status") != "ok":
        return {
            "status": "API ERROR",
            "races": [],
        }

    races = data.get("races", [])

    if type(races) != "list":
        return {
            "status": "BAD DATA",
            "races": [],
        }

    return {
        "status": "OK",
        "races": races,
    }


def _draw_race(c, ctx, race_index):
    c.fill("black")

    result = _get_races(ctx)

    if result["status"] != "OK":
        _draw_message(
            c,
            "RUNSIGNUP",
            result["status"],
            "red",
        )
        return

    races = result["races"]

    if len(races) == 0:
        _draw_message(
            c,
            "NO UPCOMING",
            "RACES",
            "amber",
        )
        return

    if race_index >= len(races):
        _draw_message(
            c,
            "NO MORE",
            "RACES",
            "#777777",
        )
        return

    race = races[race_index]

    race_name = race.get(
        "race_name",
        "UPCOMING RACE",
    )

    start_time = race.get(
        "start_time",
        "",
    )

    days = _days_until(
        start_time,
        ctx.now,
    )

    date_text = _format_date(
        start_time
    )

    race_name = race_name[:23]
    name_lines = _split_race_name(
        race_name,
        len(race_name)/2 + 1,
    )

    # Race name on two lines.
    c.text(
        name_lines["line1"],
        32,
        1,
        font = "5x5",
        color = "white",
        align = "center",
    )

    if name_lines["line2"] != "":
        c.text(
            name_lines["line2"],
            32,
            7,
            font = "5x5",
            color = "white",
            align = "center",
        )

    # Countdown.
    if days == None:
        c.text(
            date_text.upper(),
            32,
            14,
            font = "7x12",
            color = "amber",
            align = "center",
        )
    elif days > 1:
        c.text(
            (str(days) + " DAYS").upper(),
            32,
            14,
            font = "7x12",
            color = "green",
            align = "center",
        )
    elif days == 1:
        c.text(
            "TOMORROW",
            32,
            14,
            font = "7x12",
            color = "amber",
            align = "center",
        )
    elif days == 0:
        c.text(
            "RACE DAY",
            32,
            14,
            font = "7x12",
            color = "green",
            align = "center",
        )
    else:
        c.text(
            date_text.upper(),
            32,
            14,
            font = "7x12",
            color = "#777777",
            align = "center",
        )

    # Date only.
    c.text(
        date_text.upper(),
        32,
        26,
        font = "5x5",
        color = "#AAAAAA",
        align = "center",
    )


def race1(c, ctx):
    _draw_race(c, ctx, 0)


def race2(c, ctx):
    _draw_race(c, ctx, 1)


def race3(c, ctx):
    _draw_race(c, ctx, 2)