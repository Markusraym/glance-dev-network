# Citi Bike
#
# Bikes and docks at one station, from NYC's public GBFS feed. No key.
#
# The station list is baked in rather than fetched. GBFS splits the data in
# two: station_status carries the live counts, station_information carries the
# names -- and information is ~1.36 MB for 2,509 stations, which is a lot of
# bytes to move on every render just to turn an id into a label that never
# changes. Only the status feed is fetched.
#
# Both numbers are shown on purpose. Bikes tells you whether you can start a
# ride; docks tells you whether you can end one, and a full station is just as
# stuck as an empty one.

STATUS_URL = "https://gbfs.citibikenyc.com/gbfs/en/station_status.json"

STATIONS = {
    "1 AVE AT E 44 ST": "66dc2172-0aca-11e7-82f6-3863bb44ef7c",
    "1 AVE AT E 6 ST": "c37931bb-8571-4671-a9a8-f3cf23897680",
    "10 AVE AT W 14 ST": "116dbc02-a3c1-4b65-9f73-2a09a2aa1379",
    "2 AVE AT E 31 ST": "1893622839585237496",
    "3 ST AT 3 AVE": "66de25bd-0aca-11e7-82f6-3863bb44ef7c",
    "7 AVE AT CENTRAL PARK SOUTH": "b94cc90e-9ca2-4471-8371-23be051e0157",
    "7 AVE S AT BLEECKER ST": "c466f15e-715f-411e-904e-1a71fb574cdd",
    "8 AVE AT W 31 ST": "66ddbd20-0aca-11e7-82f6-3863bb44ef7c",
    "8 AVE AT W 33 ST": "66dc686c-0aca-11e7-82f6-3863bb44ef7c",
    "9 AVE AT W 18 ST": "66dc11a7-0aca-11e7-82f6-3863bb44ef7c",
    "9 AVE AT W 22 ST": "66dc7a7d-0aca-11e7-82f6-3863bb44ef7c",
    "9 AVE AT W 33 ST": "1869743938848725856",
    "ALLEN ST AT HESTER ST": "1960020817312746312",
    "BROADWAY AT E 14 ST": "66db6387-0aca-11e7-82f6-3863bb44ef7c",
    "BROADWAY AT E 19 ST": "1975518133370609774",
    "BROADWAY AT W 25 ST": "daefc84c-1b16-4220-8e1f-10ea4866fdc7",
    "BROADWAY AT W 29 ST": "66dc4bd9-0aca-11e7-82f6-3863bb44ef7c",
    "BROADWAY AT W 48 ST": "64f0f28c-bedc-42d5-b107-ecdd48fc30cd",
    "BROADWAY AT W 53 ST": "66dc2c78-0aca-11e7-82f6-3863bb44ef7c",
    "CENTRAL PARK S AT GRAND ARMY PLAZA": "1964061627836181486",
    "CENTRE ST AT WORTH ST": "66dbe848-0aca-11e7-82f6-3863bb44ef7c",
    "COOPER SQUARE AT ASTOR PL": "66ddd545-0aca-11e7-82f6-3863bb44ef7c",
    "E 10 ST AT AVE A": "66dc1beb-0aca-11e7-82f6-3863bb44ef7c",
    "E 11 ST AT 3 AVE": "a4368364-fa79-493c-8478-1d3471a6077f",
    "E 11 ST AT BROADWAY": "66dbc860-0aca-11e7-82f6-3863bb44ef7c",
    "E 13 ST AT AVE A": "d9160982-2d9b-4f08-9469-a559a7b62809",
    "E 2 ST AT AVE B": "66db6aae-0aca-11e7-82f6-3863bb44ef7c",
    "E 2 ST AT AVE C": "66db2f4c-0aca-11e7-82f6-3863bb44ef7c",
    "E 20 ST AT 2 AVE": "66dc259a-0aca-11e7-82f6-3863bb44ef7c",
    "E 24 ST AT PARK AVE S": "66dc6a86-0aca-11e7-82f6-3863bb44ef7c",
    "E 27 ST AT 1 AVE": "66dc9223-0aca-11e7-82f6-3863bb44ef7c",
    "E 33 ST AT 1 AVE": "61c82689-3f4c-495d-8f44-e71de8f04088",
    "E 40 ST AT 5 AVE": "66db30e0-0aca-11e7-82f6-3863bb44ef7c",
    "E 40 ST AT PARK AVE": "c638ec67-9ac0-416f-944f-619926144931",
    "E 47 ST AT 2 AVE": "66db32fb-0aca-11e7-82f6-3863bb44ef7c",
    "E 47 ST AT PARK AVE": "66dbc982-0aca-11e7-82f6-3863bb44ef7c",
    "E 6 ST AT AVE B": "66db76a1-0aca-11e7-82f6-3863bb44ef7c",
    "FDR DRIVE AT E 35 ST": "66dc7659-0aca-11e7-82f6-3863bb44ef7c",
    "GANSEVOORT ST AT HUDSON ST": "1827839088308194240",
    "GRAND ST AT SAMUEL DICKSTEIN PLAZA": "8cb0375d-bcb2-4c90-9773-41c3c8fdf8d8",
    "GREENWICH ST AT W HOUSTON ST": "66dbbeda-0aca-11e7-82f6-3863bb44ef7c",
    "LAFAYETTE ST AT ASTOR PL": "2245650716933709032",
    "LAIGHT ST AT HUDSON ST": "66db402c-0aca-11e7-82f6-3863bb44ef7c",
    "LEXINGTON AVE AT E 24 ST": "66dc8a3d-0aca-11e7-82f6-3863bb44ef7c",
    "LEXINGTON AVE AT E 26 ST": "454b4a83-d0b1-42a2-8163-261e2a9d6ab9",
    "OLD SLIP AT SOUTH ST": "ff2869f0-4381-4cf3-863e-a0d776ec53b4",
    "PARK AVE AT E 41 ST": "66dc7f02-0aca-11e7-82f6-3863bb44ef7c",
    "PARK AVE AT E 42 ST": "66dc8025-0aca-11e7-82f6-3863bb44ef7c",
    "RIVERSIDE BLVD AT W 67 ST": "66dd51e6-0aca-11e7-82f6-3863bb44ef7c",
    "RIVERSIDE DR AT W 78 ST": "66dd5407-0aca-11e7-82f6-3863bb44ef7c",
    "VESEY ST AT GREENWICH ST": "1989279523593928720",
    "W 20 ST AT 8 AVE": "66dc36c3-0aca-11e7-82f6-3863bb44ef7c",
    "W 31 ST AT 7 AVE": "66dbe4db-0aca-11e7-82f6-3863bb44ef7c",
    "W 34 ST AT 11 AVE": "66dc8382-0aca-11e7-82f6-3863bb44ef7c",
    "W 37 ST AT BROADWAY": "341730d7-a61d-499d-8c07-fa015f644e54",
    "W 41 ST AT 8 AVE": "66dc3f08-0aca-11e7-82f6-3863bb44ef7c",
    "W 43 ST AT 10 AVE": "66dc7de9-0aca-11e7-82f6-3863bb44ef7c",
    "W 51 ST AT 6 AVE": "66dc7b10-0aca-11e7-82f6-3863bb44ef7c",
    "W 59 ST AT 10 AVE": "66dc0dab-0aca-11e7-82f6-3863bb44ef7c",
    "W BROADWAY AT SPRING ST": "bde94a25-6089-4490-af3a-8cc5702230b8",
}


NODATA_FONTS = ["10x16", "6x8", "5x7", "4x5"]


def _fit_clip(c, text, fonts, maxw):
    """[font, text] for the largest font that fits, clipping if none do."""
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
    """Shown whenever the feed is unreachable. The publish-time validator
    renders with the network disabled, so this has to say something."""
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


def resolve_station(ctx):
    """Station id for the picked stop, or "" when it is not one of ours."""
    v = ctx.inputs.get("station", "")
    if v == None:
        v = ""
    v = str(v).strip().upper()
    if v in STATIONS:
        return STATIONS[v]
    return ""


def band(n):
    """Colour for a count. Zero is the whole point of looking, so it is red."""
    if n <= 0:
        return "#FF5B5B"
    if n <= 3:
        return "#FFB03A"
    return "#4EE38A"


def bikes(c, ctx):
    sid = resolve_station(ctx)
    if sid == "":
        nodata(c, "PICK A STATION", "IN SETTINGS")
        return

    r = http.get(STATUS_URL, ttl_seconds = 120)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO CITI BIKE DATA", "FEED UNREACHABLE")
        return

    found = None
    for s in r["json"].get("data", {}).get("stations", []):
        if str(s.get("station_id", "")) == sid:
            found = s
            break
    if found == None:
        nodata(c, "STATION GONE", "PICK ANOTHER")
        return

    total = int(found.get("num_bikes_available", 0) or 0)
    ebikes = int(found.get("num_ebikes_available", 0) or 0)
    docks = int(found.get("num_docks_available", 0) or 0)
    classic = total - ebikes
    if classic < 0:
        classic = 0

    # A station can be installed but not renting or not returning; the counts
    # look normal in that case and the trip still fails.
    shut = ""
    if not found.get("is_renting", True):
        shut = "NOT RENTING"
    elif not found.get("is_returning", True):
        shut = "NOT RETURNING"

    name = str(ctx.inputs.get("station", "")).strip().upper()

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#06120A", "#123322",
                    horizontal = False)

    if c.width >= 128:
        # Three rows, all left-anchored at the same edge, so no pair can grow
        # into another as the counts change width.
        nf = _fit_clip(c, name, ["5x7", "4x5"], c.width - 8)
        c.text(nf[1], 4, 0, font = nf[0], color = "#7FB6A0")
        c.text(str(total), 4, 9, font = "16x20", color = band(total))
        x = 4 + c.text_width(str(total), "16x20") + 5
        c.text("BIKES", x, 10, font = "5x7", color = "#9CC4B0")
        c.text(str(ebikes) + " E", x, 19, font = "5x7", color = "#7FB6E8")
        right = str(docks) + " DOCKS"
        c.text(right, c.width - 4, 12, font = "6x8", color = band(docks),
               align = "right")
        if shut != "":
            c.text(shut, c.width - 4, 24, font = "5x7", color = "#FF7A5B",
                   align = "right")
    else:
        # 64px will not carry a 16x20 count AND a label beside it: three
        # digits is 51px of the 62 available, which squeezed "BIKES" down to
        # "BI". Two labelled lines instead -- both numbers stay readable and
        # neither can be mistaken for the other, which matters more here than
        # a big number does.
        nf = _fit_clip(c, name, ["4x5"], c.width - 4)
        c.text(nf[1], 2, 0, font = nf[0], color = "#7FB6A0")
        bf = _fit_clip(c, str(total) + " BIKES", ["6x8", "5x7"], c.width - 4)
        c.text(bf[1], 2, 9, font = bf[0], color = band(total))
        df = _fit_clip(c, str(docks) + " DOCKS", ["6x8", "5x7"], c.width - 4)
        c.text(df[1], 2, 19, font = df[0], color = band(docks))
        if shut != "":
            c.text(_fit_clip(c, shut, ["4x5"], c.width - 4)[1], 2, 27,
                   font = "4x5", color = "#FF7A5B")
