RANDOM_URL = "https://random-word-api.herokuapp.com/word?number=2&diff=4"
DICTIONARY_URL = "https://api.dictionaryapi.dev/api/v2/entries/en/"

CHARS_PER_LINE = 16
LINES_PER_PAGE = 4


def _clean_text(value):
    if value == None:
        return ""

    text = str(value)

    text = text.replace("\n", " ")
    text = text.replace("\r", " ")

    return text


def _wrap_lines(text, max_chars):
    words = str(text).upper().split(" ")

    lines = []
    current = ""

    for item in words:
        if item != "":
            if current == "":
                candidate = item
            else:
                candidate = current + " " + item

            if len(candidate) <= max_chars:
                current = candidate

            else:
                if current != "":
                    lines.append(current)

                if len(item) <= max_chars:
                    current = item
                else:
                    lines.append(item[:max_chars])
                    current = ""

    if current != "":
        lines.append(current)

    return lines


def _lookup_word(word):
    resp = http.get(
        DICTIONARY_URL + word,
        ttl_seconds = 86400,
    )

    if resp["status_code"] != 200:
        return None

    entries = resp["json"]

    if entries == None or len(entries) == 0:
        return None

    entry = entries[0]

    meanings = entry.get("meanings", [])

    if meanings == None or len(meanings) == 0:
        return None

    fallback_definition = ""
    fallback_part = ""

    selected_definition = ""
    selected_part = ""
    selected_example = ""

    for meaning in meanings:
        part = _clean_text(
            meaning.get("partOfSpeech", "")
        )

        definitions = meaning.get("definitions", [])

        if definitions != None:
            for item in definitions:
                definition_text = _clean_text(
                    item.get("definition", "")
                )

                example_text = _clean_text(
                    item.get("example", "")
                )

                if (
                    fallback_definition == ""
                    and definition_text != ""
                ):
                    fallback_definition = definition_text
                    fallback_part = part

                if (
                    selected_example == ""
                    and definition_text != ""
                    and example_text != ""
                ):
                    selected_definition = definition_text
                    selected_part = part
                    selected_example = example_text

    if selected_definition != "":
        return {
            "word": word,
            "part": selected_part,
            "definition": selected_definition,
            "example": selected_example,
            "has_example": True,
        }

    if fallback_definition != "":
        return {
            "word": word,
            "part": fallback_part,
            "definition": fallback_definition,
            "example": "",
            "has_example": False,
        }

    return None


def _get_data(ctx):
    resp = http.get(
        RANDOM_URL,
        ttl_seconds = 86400,
    )

    if resp["status_code"] != 200:
        return {
            "error": "WORD API ERROR",
        }

    words = resp["json"]

    if words == None or len(words) == 0:
        return {
            "error": "NO WORD",
        }

    for raw_word in words:
        word_text = _clean_text(raw_word)

        if word_text != "":
            data = _lookup_word(word_text)

            if data != None:
                return data

    return {
        "error": "NO DEFINITION",
    }


def _draw_error(c, message):
    c.fill("black")

    c.text(
        "WORD OF DAY",
        32,
        6,
        font = "5x7",
        color = "amber",
        align = "center",
    )

    c.text(
        str(message).upper(),
        32,
        18,
        font = "picopixel",
        color = "red",
        align = "center",
    )


def _draw_word(c, word_text):
    word_text = word_text.upper()
    length = len(word_text)

    if length <= 6:
        font = "7x12"
        y = 5

    elif length <= 8:
        font = "6x8"
        y = 7

    elif length <= 10:
        font = "5x7"
        y = 7

    elif length <= 12:
        font = "4x5"
        y = 8

    else:
        font = "picopixel"
        y = 9

    c.text(
        word_text,
        32,
        y,
        font = font,
        color = "white",
        align = "center",
    )


def _draw_lines(c, label, lines, start, count, color):
    c.fill("black")

    c.text(
        label.upper(),
        2,
        1,
        font = "picopixel",
        color = color,
    )

    y = 8
    end = start + count

    if end > len(lines):
        end = len(lines)

    for index in range(start, end):
        c.text(
            lines[index].upper(),
            2,
            y,
            font = "picopixel",
            color = "white",
        )

        y = y + 6


def word(c, ctx):
    data = _get_data(ctx)

    if data.get("error", "") != "":
        _draw_error(
            c,
            data["error"],
        )

    else:
        c.fill("black")

        _draw_word(
            c,
            data["word"],
        )

        part = data["part"]

        if part == "":
            part = "WORD"

        c.text(
            part.upper(),
            32,
            24,
            font = "5x7",
            color = "amber",
            align = "center",
        )


def definition(c, ctx):
    data = _get_data(ctx)

    if data.get("error", "") != "":
        _draw_error(
            c,
            data["error"],
        )

    else:
        lines = _wrap_lines(
            data["definition"],
            CHARS_PER_LINE,
        )

        label = "DEFINITION"

        if len(lines) > LINES_PER_PAGE:
            label = "DEFINITION  1/2"

        _draw_lines(
            c,
            label,
            lines,
            0,
            LINES_PER_PAGE,
            "green",
        )


def details(c, ctx):
    data = _get_data(ctx)

    if data.get("error", "") != "":
        _draw_error(
            c,
            data["error"],
        )

    else:
        definition_lines = _wrap_lines(
            data["definition"],
            CHARS_PER_LINE,
        )

        if len(definition_lines) > LINES_PER_PAGE:
            _draw_lines(
                c,
                "DEFINITION  2/2",
                definition_lines,
                LINES_PER_PAGE,
                LINES_PER_PAGE,
                "green",
            )

        else:
            example_text = data["example"]

            if example_text == "":
                example_text = "NO EXAMPLE AVAILABLE"

            example_lines = _wrap_lines(
                example_text,
                CHARS_PER_LINE,
            )

            _draw_lines(
                c,
                "EXAMPLE",
                example_lines,
                0,
                LINES_PER_PAGE,
                "blue",
            )