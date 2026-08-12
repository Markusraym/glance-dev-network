# Ported from the tidbyt/community "Biorhythm" app (apps/biorhythm/biorhythm.star).
#
# ORIGINAL Pixlet: computes days since your birthdate, then draws three sine
# waves (Physical 23d, Emotional 28d, Intellectual 33d) with three render.Plot
# scatter charts stacked in a render.Stack, labelled -P- -E- -I-.
#
# `gdn translate` converted the schema.DateTime and flagged humanize/time/math/
# load() and the Stack/Column/Row/Box/Plot/Text widgets. Hand-finished for GDN
# (static 64x32): the DATE-DIFF + SINE MATH port verbatim; render.Plot became
# c.line sparklines (GDN has no Plot widget) across a +/-16 day window centered
# on today, with a "today" marker and a P/E/I legend.

PI2 = 6.283185307179586

# Serial-day date difference (ported from the original dateDiff()).
def date_diff(d1, m1, y1, d2, m2, y2):
    m1 = float((m1 + 9) % 12)
    y1 = y1 - m1 / 10.0
    x1 = 365 * y1 + y1 / 4 - y1 / 100 + y1 / 400 + (m1 * 306 + 5) / 10 + (d1 - 1)
    m2 = float((m2 + 9) % 12)
    y2 = y2 - m2 / 10.0
    x2 = 365 * y2 + y2 / 4 - y2 / 100 + y2 / 400 + (m2 * 306 + 5) / 10 + (d2 - 1)
    return x2 - x1

DEFAULT_BDAY = [1990, 6, 15]

def _digits(s):
    out = ""
    for i in range(len(s)):
        ch = s[i]
        if ch >= "0" and ch <= "9":
            out = out + ch
    return out

def parse_bday(ctx):
    """Read the birthdate without trusting its shape.

    It was read as dt[0:4] / dt[5:7] / dt[8:10], which assumes exactly
    "YYYY-MM-DD" and nothing else. Two ways that bites:

      - Hyphens are render-descriptor delimiters (key-value_key-value), so a
        value carrying them is fragile in transit. Arriving as "19900615"
        makes dt[8:10] the empty string, and int("") is a hard error -- the
        panel goes blank rather than showing a wrong date.
      - An unset input can come back as None, which subscripts straight into
        an error too.

    Reducing to digits accepts either spelling, and anything short or
    implausible falls back to the default instead of taking the panel down.
    """
    v = ctx.inputs.get("bday", "")
    if v == None:
        v = ""
    ds = _digits(str(v))
    if len(ds) < 8:
        return DEFAULT_BDAY
    y = int(ds[0:4])
    m = int(ds[4:6])
    d = int(ds[6:8])
    if y < 1900 or m < 1 or m > 12 or d < 1 or d > 31:
        return DEFAULT_BDAY
    return [y, m, d]

def main(c, ctx):
    b = parse_bday(ctx)
    by = b[0]
    bm = b[1]
    bd = b[2]
    n = ctx.now
    dD = date_diff(bd, bm, by, n.day, n.month, n.year)

    c.fill("black")
    cy = 14
    amp = 11.0
    half = c.width / 2.0

    # zero line and "today" marker
    c.line(0, cy, c.width - 1, cy, "#333333")
    c.line(c.width // 2, 1, c.width // 2, c.height - 8, "midgray")

    # (period, color) for Physical / Emotional / Intellectual
    curves = [(23, "yellow"), (28, "red"), (33, "blue")]
    for j in range(len(curves)):
        period, color = curves[j]
        px = -1
        py = -1
        for x in range(c.width):
            day = dD + (x - half) / 2.0        # 2 px per day, centered on today
            y = int(cy - amp * math.sin(PI2 * day / period) + 0.5)
            if px >= 0:
                c.line(px, py, x, y, color)
            px = x
            py = y

    # legend along the bottom
    c.text("P", 6, c.height - 6, font = "4x5", color = "yellow", align = "center")
    c.text("E", c.width // 2, c.height - 6, font = "4x5", color = "red", align = "center")
    c.text("I", c.width - 6, c.height - 6, font = "4x5", color = "blue", align = "center")
