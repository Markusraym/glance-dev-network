# Days Since — a streak counter for the thing you are keeping up, or keeping
# away from.
#
# Page one is the number, big enough to read across a room. Page two breaks the
# same streak down into weeks, months and the date it started, which is the part
# people actually want once the number gets large.
#
# Pure date arithmetic from ctx.now — no network, so it cannot show a stale or
# empty screen.

MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


def days_from_civil(y, m, d):
    """Days since the Unix epoch (Howard Hinnant's algorithm)."""
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    mp = m - 3 if m > 2 else m + 9
    doy = (153 * mp + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468


DIGITS = "0123456789"
FALLBACK = [2026, 1, 1]


def parse_date(s):
    """YYYY-MM-DD -> [y, m, d].

    Starlark has no exceptions, so every character is validated by hand before
    it is used: a typo in the setting falls back to a sane date instead of
    crashing the render and blanking the panel."""
    parts = str(s).split("-")
    if len(parts) != 3:
        return FALLBACK

    out = []
    for p in parts:
        if len(p) == 0:
            return FALLBACK
        n = 0
        for i in range(len(p)):
            d = DIGITS.find(p[i])
            if d < 0:
                return FALLBACK
            n = n * 10 + d
        out.append(n)

    if out[1] < 1 or out[1] > 12 or out[2] < 1 or out[2] > 31:
        return FALLBACK
    return out


def streak(ctx):
    start = parse_date(ctx.inputs.get("since", "2026-01-01"))
    today = days_from_civil(ctx.now.year, ctx.now.month, ctx.now.day)
    n = today - days_from_civil(start[0], start[1], start[2])
    return [n if n > 0 else 0, start]


def count(c, ctx):
    n = streak(ctx)[0]
    label = ctx.inputs.get("label", "DAYS SINCE").upper()
    accent = ctx.inputs.get("accent", "#39D98A")

    c.fill("#08090D")
    numstr = fmt.commas(n)

    if c.width >= 128:
        # A long label must shrink rather than run off the edge.
        c.text_fit(label, 6, 1, ["6x8", "5x7", "4x5"], color = accent,
                   maxw = c.width - 12)
        # Shrink the figure only if the streak outgrows the space.
        f = c.text_fit(numstr, 6, 11, ["16x20", "10x16", "7x12"],
                       color = "#FFFFFF", maxw = c.width - 12)
        c.text("DAY" if n == 1 else "DAYS", c.width - 6, 14, font = "6x8",
               color = "#5E5E7A", align = "right")
    else:
        # 0-4 label | 7-26 figure | 27-31 unit
        # 0-4 label | 5-24 figure | 26-30 unit, row 31 left as margin.
        c.text_fit(label, c.width // 2, 0, ["4x5", "3x4"], color = accent,
                   align = "center", maxw = c.width - 2)
        c.text_fit(numstr, c.width // 2, 5, ["16x20", "10x16", "7x12"],
                   color = "#FFFFFF", align = "center", maxw = c.width - 4)
        c.text("DAY" if n == 1 else "DAYS", c.width // 2, 26, font = "4x5",
               color = "#8A8AA8", align = "center")


def detail(c, ctx):
    s = streak(ctx)
    n = s[0]
    start = s[1]
    accent = ctx.inputs.get("accent", "#39D98A")

    c.fill("#08090D")
    since = "%s %d %d" % (MONTHS[start[1] - 1], start[2], start[0])
    weeks = n // 7
    months = n // 30

    if c.width >= 128:
        c.text("SINCE " + since, 6, 1, font = "5x7", color = accent)
        c.text(str(weeks) + " WEEKS", 6, 12, font = "6x8", color = "#FFFFFF")
        c.text(str(months) + " MONTHS", 6, 22, font = "6x8", color = "#9A9AB8")
        c.text(fmt.commas(n), c.width - 6, 10, font = "16x20",
               color = "#FFFFFF", align = "right")
    else:
        # The narrow panel has no room for the figure as well — page one
        # already carries it, so this page is purely the breakdown.
        # 0-4 date | 9-16 weeks | 19-26 months
        c.text(since, c.width // 2, 0, font = "4x5", color = accent,
               align = "center")
        c.text(str(weeks) + " WEEKS", c.width // 2, 9, font = "6x8",
               color = "#FFFFFF", align = "center")
        c.text(str(months) + " MONTHS", c.width // 2, 19, font = "6x8",
               color = "#9A9AB8", align = "center")
