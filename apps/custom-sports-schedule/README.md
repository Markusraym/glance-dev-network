# Prout School Sports

Upcoming soccer and volleyball games for **The Prout School** in Wakefield, Rhode
Island — a sport icon, both team logos, the opponent's name and the kickoff time.

Ships as a pair: **`custom-sports-schedule`** (192x32) and
**`custom-schedule-classic`** (64x32). Same schedule, different panel width.

The app id still reads `custom-sports-schedule` because changing it would break
every panel that already has it installed, and the render descriptor with it.
Only the display name changed.

## Settings

None. There is nothing to fill in.

## The schedule is a hardcoded snapshot, not a live feed

This is the part worth knowing. The games come from a
[Google Sheet](https://docs.google.com/spreadsheets/d/1RAdODqjHvG5g7sagBCOCgtmuwggMEKTpZcYrktJw1NY),
but they are **baked into `app.star`** rather than read at render time — so the
panel shows whatever the last seven games were when the snapshot was taken, and
it does not update itself.

It is a snapshot because most of the sheet's logo columns are `file://` paths on
the original author's laptop, which nothing else can fetch. A live version needs
those logos hosted somewhere reachable first; until then, refreshing the
schedule means editing `GAMES` in `app.star` and re-submitting.

Colours come from the sheet's own home/away colour columns. A team whose name is
too wide for the name column falls back to the sheet's abbreviation rather than
shrinking the font.

## Pages

A title card, then one page per game — seven of them, because the scene schema
caps every app at eight pages.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it**. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
