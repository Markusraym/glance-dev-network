# Currency Rates
#
# open.er-api.com, keyless, which answers in about 80ms. The
# dropdowns list exactly the codes it serves, so nothing offered
# can fail to resolve.
#
# Frankfurter was the first choice and had to be abandoned: it
# serves the same ECB rates but takes over four seconds to reply,
# and the platform aborts any request at four. It worked fine in a
# browser and failed every time on the panel.



NODATA_FONTS = ["10x16", "6x8", "5x7", "4x5"]


def _fit_clip(c, text, fonts, maxw):
    """[font, text] for the largest font that fits, clipping if none do.

    text_fit alone was not enough here: when even its smallest option
    overflows it still draws, which ran these messages off a 64 panel."""
    pick = fonts[len(fonts) - 1]
    for f in fonts:
        if c.text_width(text, f) <= maxw:
            pick = f
            break
    t = text
    if c.text_width(t, pick) > maxw:
        for k in range(len(t), 0, -1):
            if c.text_width(t[:k], pick) <= maxw:
                t = t[:k]
                break
    return [pick, t]


def nodata(c, title, sub):
    """Shown whenever a feed is unreachable or a key is missing.

    Every network app needs one: the publish-time validator renders each page
    with the network disabled, and a panel on a wall must say something
    sensible rather than going blank.

    The two lines get explicit, non-overlapping bands — a 16px title centred
    on the panel ran straight through the line beneath it.
    Wide:   4-19 title | 22-28 detail
    Narrow: 5-12 title | 18-22 detail
    """
    c.fill("#0B0C12")
    maxw = c.width - 6
    if c.width >= 128:
        t = _fit_clip(c, title, NODATA_FONTS, maxw)
        c.text(t[1], c.width // 2, 4, font = t[0], color = "#E8B04A",
               align = "center")
        d = _fit_clip(c, sub, ["5x7", "4x5"], maxw)
        c.text(d[1], c.width // 2, 22, font = d[0], color = "#6A7090",
               align = "center")
    else:
        t = _fit_clip(c, title, ["6x8", "5x7", "4x5"], maxw)
        c.text(t[1], c.width // 2, 5, font = t[0], color = "#E8B04A",
               align = "center")
        d = _fit_clip(c, sub, ["4x5"], maxw)
        c.text(d[1], c.width // 2, 18, font = d[0], color = "#6A7090",
               align = "center")


def rates(c, ctx):
    base = str(ctx.inputs.get("base", "USD")).strip().upper()
    want = []
    # Three slots rather than one comma-separated box: every combination of
    # three from 166 currencies is millions of dropdown entries.
    for k in ["curone", "curtwo", "curthree"]:
        v = str(ctx.inputs.get(k, "")).strip().upper()
        if v != "" and v != "NONE" and v != base and v not in want:
            want.append(v)
    if base == "" or len(want) == 0:
        nodata(c, "NOT CONFIGURED", "PICK CURRENCIES")
        return

    r = http.get("https://open.er-api.com/v6/latest/" + base,
                 ttl_seconds = 3600)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO RATES", "NO CONNECTION")
        return
    got = r["json"].get("rates", {})
    if len(got) == 0:
        nodata(c, "NO RATES", "CHECK THE CODES")
        return

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#100C04", "#2A2008",
                    horizontal = False)
    sz = 24 if c.width >= 128 else 16
    c.image("COINS.png", 1, (c.height - sz) // 2, w = sz, h = sz)

    rows = []
    for w in want:
        v = got.get(w, None)
        if v != None:
            rows.append([w, float(v)])
    if len(rows) == 0:
        nodata(c, "NO RATES", "CHECK THE CODES")
        return

    x0 = 28 if c.width >= 128 else 19
    lh = c.height // len(rows)
    for i in range(len(rows)):
        y = i * lh + (lh - 7) // 2
        v = rows[i][1]
        if c.width >= 128:
            shown = str(int(v * 10000) / 10000.0) if v < 10 else str(int(v * 100) / 100.0)
            c.text(rows[i][0], x0, y, font = "5x7", color = "#C8A860")
            c.text(shown, c.width - 3, y, font = "5x7", color = "#FFE8A8",
                   align = "right")
        else:
            # A 5x7 code plus a four-decimal rate is wider than 45px, so the
            # small panel drops to 4x5 and two decimals.
            # Six characters of value plus a three-letter code do not fit
            # 45px, so large rates lose their decimals entirely.
            shown = str(int(v)) if v >= 100 else str(int(v * 100) / 100.0)
            c.text(rows[i][0], x0, y + 1, font = "4x5", color = "#C8A860")
            c.text(shown, c.width - 2, y + 1, font = "4x5", color = "#FFE8A8",
                   align = "right")
