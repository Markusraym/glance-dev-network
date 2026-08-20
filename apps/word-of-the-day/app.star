RANDOM_URL = "https://random-word-api.herokuapp.com/word?number=2&diff=4"
DICTIONARY_URL = "https://api.dictionaryapi.dev/api/v2/entries/en/"

FONT = "picopixel"
# Text starts at TEXT_X and keeps the same gutter on the right.
TEXT_X = 2
LINES_PER_PAGE = 4


def _clean_text(value):
    if value == None:
        return ""

    text = str(value)

    text = text.replace("\n", " ")
    text = text.replace("\r", " ")

    return text


def _wrap_lines(c, text, max_px):
    """Wrap on measured pixel width rather than a character count.

    picopixel is proportional -- W is 5px wide, I is 2px -- so one fixed
    character budget is wrong in both directions: it wastes a row of narrow
    letters, and it overflows on wide ones. Nothing in the drawing API
    clips, so an overflowing line just loses its last glyph off the right
    edge ("ESTER OF BENZOIC" is 16 chars but measures 63px, one column past
    a 64px panel once the 2px left margin is added).
    """
    words = str(text).upper().split(" ")

    lines = []
    current = ""

    for item in words:
        if item != "":
            if current == "":
                candidate = item
            else:
                candidate = current + " " + item

            if c.text_width(candidate, font = FONT) <= max_px:
                current = candidate

            else:
                if current != "":
                    lines.append(current)

                if c.text_width(item, font = FONT) <= max_px:
                    current = item
                else:
                    # One word wider than the whole row: break it on pixels
                    # too, so a long headword cannot run off the panel.
                    chunk = ""

                    for i in range(len(item)):
                        ch = item[i:i + 1]

                        if c.text_width(chunk + ch, font = FONT) <= max_px:
                            chunk = chunk + ch
                        else:
                            if chunk != "":
                                lines.append(chunk)
                            chunk = ch

                    current = chunk

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


# Headword sizes, largest first, each with the baseline that centres it.
WORD_FONTS = [
    ["7x12", 5],
    ["6x8", 7],
    ["5x7", 7],
    ["4x5", 8],
    ["picopixel", 9],
]


def _draw_word(c, word_text):
    word_text = word_text.upper()

    # Pick on measured width, not len(). These fonts are proportional, so a
    # character count is only ever an approximation of the real thing: at 12
    # characters "MMMMMMMMMMMM" and "IIIIIIIIIIII" want different sizes, and
    # a genuinely long headword ("ANTIDISESTABLISHMENTARIANISM" measures
    # 111px in picopixel) overflowed a 64 panel in both directions at once,
    # because nothing in the drawing API clips.
    #
    # The budget is the whole panel: this draw is centred, not indented like
    # the definition rows, so anything that measures within c.width still
    # lands on screen. Nothing that used to render fully is narrowed.
    max_px = c.width

    font = WORD_FONTS[len(WORD_FONTS) - 1][0]
    y = WORD_FONTS[len(WORD_FONTS) - 1][1]

    for pair in WORD_FONTS:
        if c.text_width(word_text, font = pair[0]) <= max_px:
            font = pair[0]
            y = pair[1]
            break

    # Longer than the smallest font can show: keep the prefix that fits so
    # the word stays on the panel instead of running off both edges.
    if c.text_width(word_text, font = font) > max_px:
        for k in range(len(word_text), 0, -1):
            if c.text_width(word_text[:k], font = font) <= max_px:
                word_text = word_text[:k]
                break

    c.text(
        word_text,
        c.width // 2,
        y,
        font = font,
        color = "white",
        align = "center",
    )


def _draw_lines(c, label, lines, start, count, color):
    c.fill("black")

    c.text(
        label.upper(),
        TEXT_X,
        1,
        font = FONT,
        color = color,
    )

    y = 8
    end = start + count

    if end > len(lines):
        end = len(lines)

    for index in range(start, end):
        c.text(
            lines[index].upper(),
            TEXT_X,
            y,
            font = FONT,
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
            c,
            data["definition"],
            c.width - TEXT_X * 2,
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
            c,
            data["definition"],
            c.width - TEXT_X * 2,
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
                c,
                example_text,
                c.width - TEXT_X * 2,
            )

            _draw_lines(
                c,
                "EXAMPLE",
                example_lines,
                0,
                LINES_PER_PAGE,
                "blue",
            )