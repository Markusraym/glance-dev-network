# Go Gophers, a gameday sign: block M on the left, SKI-U-MAH! in the middle,
# Goldy on the right, in true maroon and gold. (192x32)
#
# Same two moves as every sign app: draw PICTURES (bundled PNGs) and draw
# TEXT. The only wrinkle here is there are two pictures, one on each side, so
# the text has to center itself in whatever room is left between them.

FONT_HEIGHT = {"10x16": 16, "7x12": 12, "6x8": 8, "5x7": 7}

def fit_font(c, text, options, maxw):
    for f in options:
        if c.text_width(text, f) <= maxw:
            return f
    return options[len(options) - 1]   # nothing fit, use the smallest


def sign(c, ctx):
    msg = ctx.inputs.get("message", "SKI-U-MAH!").upper()
    maroon = ctx.inputs.get("maroon", "#7A0019")
    gold = ctx.inputs.get("gold", "#FFCC33")

    c.fill("black")

    # Logos: block M on the left, Goldy on the right, each 30x30, centered
    # in the 32px panel height (1px margin top and bottom).
    logo_w = 30
    margin = 3
    c.image("m_logo.png", margin, 1, w = logo_w, h = logo_w)
    c.image("goldy.png", c.width - logo_w - margin, 1, w = logo_w, h = logo_w)

    # The message goes between the two logos. Work out the space that's
    # left, and its horizontal center, so it stays centered there whatever
    # the message ends up being.
    tx = margin + logo_w + 3
    tw = c.width - tx - logo_w - margin - 3
    cx = tx + tw // 2

    fonts = ["10x16", "7x12", "6x8", "5x7"]
    font = fit_font(c, msg, fonts, tw)
    ty = (c.height - FONT_HEIGHT[font]) // 2

    # A 1px maroon drop-shadow under the gold text gives it some pop against
    # the black panel, like appliqued lettering on a flag.
    c.text(msg, cx + 1, ty + 1, font = font, color = maroon, align = "center")
    c.text(msg, cx, ty, font = font, color = gold, align = "center")
