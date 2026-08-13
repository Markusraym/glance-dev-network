# GO OILERS
#
# Two logos flanking the shout, nothing to configure.

def main(c, ctx):
    c.fill("black")
    c.image("tulsa_oilers_ifl_logo.png", 6, 0)
    c.image("tulsa_oilers_ifl_logo-2.png", 134, 0)
    # Centred in the gap between the logos. It used to sit at y=2 to leave
    # room for the free-text line underneath; with that gone it just floated.
    c.text_center("GO OILERS", 12, font = "6x8", color = "amber")
