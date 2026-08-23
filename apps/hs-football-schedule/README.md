# HS Football Schedule

Upcoming high school football games for one school.

Pages: `next_up`, `game1`, `game2`, `game3`, `game4`, `game5`

## Setting it up

1. Find your school on **MaxPreps** and copy the path from the URL, **including the sport** — for example `/fl/naples/naples-golden-eagles/football/`.
2. The `/football/` suffix is required. Without it the request errors.
3. Paste that into **MaxPreps team path**.
4. The data comes through a scraper on **parse.bot**, so you need a key from **<https://parse.bot>** (it starts with `pmx_`). Paste it into **parse.bot API key**.
5. Optionally pin a season with a code like `26-27`.

## Settings

| setting | what it is |
|---|---|
| **MaxPreps team path** | The team's MaxPreps path INCLUDING the sport, e.g. /fl/naples/naples-golden-eagles/football/ for Naples (FL). The sport suffix is required - the path without it returns an error. Add a se... |
| **Season (optional)** | MaxPreps season code, e.g. 26-27. Leave blank to get whichever season MaxPreps currently marks as active - note that in the off-season that is still last year's finished schedule, which w... |
| **parse.bot API key** *(credential)* | Your parse.bot key (starts with pmx_), from the dashboard at https://parse.bot. Not needed while the school is set to DEMO. |

## Notes

- Leave the school set to `DEMO` and no key is needed — useful for seeing the layout first.
- In the off-season MaxPreps still marks last year's finished schedule as active, so the panel will show completed games until the new season opens. Pin a season code to control that.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
