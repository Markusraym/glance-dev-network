# Local Closings

Local Closings is a Glance Scroll weather app by John McRae. It shows **school, business, daycare, church, government, and organization closings and delays** from a Closings & Delays webpage you paste in. No API key is required.

![Closed school](preview/closing-one.png)

![Delay](preview/closing-two.png)

![Closings board](preview/closing-board.png)

**Local Closings only displays what the configured public source reported.** Typing a school name does not look the school up, and it does not add a school the source did not list.

## How to use

1. Open your local TV, radio, or news site and find the **Closings & Delays** (or School Closings) page. It is often under Weather.
2. Copy that page's URL and paste it into **Closings Website URL**. You can omit `https://`.
3. Optionally type your **School Name**. If that name appears in a reported listing, it is shown first and tagged **YOUR SCHOOL**.
4. If the panel says **SOURCE NOT SUPPORTED**, that station's site is not one the app can read. Try **another station that is local to your school** — a different channel in the same city, a sister station, or a nearby market that also posts closings for your district. One local site may work when another does not.

Not every website works. Glance cannot run the JavaScript that fills many tables, so the app only reads known closings systems (Gray, TownNews, Nexstar, NBC, Scripps/FlashAlert, TEGNA, Hearst, FOX/Sinclair WorldNow, CBS Newsroom XML, Cox, Arc SchoolClosings, and similar). An unsupported page shows **SOURCE NOT SUPPORTED**, not a guessed list of headlines. Stations in the same town often use different systems, so switching to another local Closings page is the usual fix.

## What you will see

| Page | Meaning |
|------|---------|
| **board** | How many closings the source reported, or **NO REPORTED CLOSINGS** if the feed is empty |
| **one** … **five** | One organization at a time: name, status (`CLOSED`, `2 HR DELAY`, …), optional detail |

| Panel text | Meaning |
|------------|---------|
| **NO REPORTED CLOSINGS** | The source was read and currently lists nothing. In summer this is common. |
| **SOURCE NOT SUPPORTED** | That website is not a known closings family. Paste a Closings page from **another station local to your school**. |
| **SOURCE UNAVAILABLE** | The page did not load (typo, timeout, or the site blocked the request). |
| **YOUR SCHOOL FIRST** | Your school name matched at least one reported listing. |

A missing school on a day with other closings means **the station did not publish that name**. The app will not invent it.

## Preview

From the Glance Developer Network repository:

```powershell
pip install -e .
gdn studio apps/local-closings
```

Browser-only preview:

```powershell
gdn preview apps/local-closings
```

If `gdn` is not on `PATH`, use `python -m gdn.cli` instead.

In Studio, paste a Closings URL. Try a school name if that organization is on the list — it jumps to page one.

## Configuration

| Setting | Default | Notes |
|---------|---------|--------|
| **School Name** | *(blank)* | Optional. Case does not matter. `WABASH` matches `WABASH CITY SCHOOLS`. Generic words like `SCHOOL` are ignored. Long names are shortened in the header (`HIGH SCHOOL` → `HS`) only if they do not fit. |
| **Closings Website URL** | `www.21alivenews.com/weather/closings/` | Paste the Closings & Delays page. `https://` is added if omitted (defaults cannot contain `:` in GDN render descriptors). |

Panel size is **192×32**. Refresh is **300 seconds**. HTTP TTL is **300 seconds**, so every page of one render reuses the same fetch.

There is **no custom database inside a GDN app**. Only the configured inputs and live HTTP requests are used.

## Pages

| Page | Contents |
|------|----------|
| **board** | LOCAL CLOSINGS, optional school name, reported count — or **NO REPORTED CLOSINGS** |
| **one** … **five** | One organization at a time: name, normalized status, optional detail. A matched school is listed first. |

## Supported sources

The public webpage table is often filled by JavaScript. Glance cannot run that JS, so the app does **not** scrape arbitrary HTML. After it recognizes a closings **technology family**, it loads the small public feed or server-rendered listing that family uses.

| Family | Example URL | Live feed |
|--------|-------------|-----------|
| **Gray GSync / NewsTicker** | `https://www.21alivenews.com/weather/closings/` | `{origin}/pf/api/v3/content/fetch/gsync-closings` (NewsTicker XML fallback). Also used by some Allen Media stations. |
| **TownNews / BLOX** | `https://www.koamnewsnow.com/weather/closings-and-delays/` | `{origin}/app/closings/*.xml` (`<Closing>` / empty `<File>`) |
| **Nexstar WordPress** | `https://www.ksn.com/closings/` | PSG iframe at `media.psg.nexstardigital.net/...` |
| **Nexstar WordPress** | `https://www.fourstateshomepage.com/weather/closings/` | WordPress `wp-json/wp/v2/pages?slug=closings` (the HTML page is 403 to Glance) |
| **NBC O&O WordPress** | `https://www.nbcdfw.com/weather/school-closings/` | Page HTML (`closings--inactive` / listing rows) plus `{origin}/wp-json/nbc/v1/school-closings` |
| **Scripps Brightspot / FlashAlert** | `https://www.koaa.com/weather/school-closings-delays` | Page HTML (`module--closings`) or FlashAlert `cwc-closures.php?RegionID=` |
| **FlashAlert iframe** | `https://katu.com/weather/closings` | Follows `flashalertnewswire.net` iframe (Sinclair KATU uses FlashAlert, not a Sinclair-wide CMS) |
| **WorldNow orgname HTML** | `https://www.fox5ny.com/closings` | `media.foxtv.com/{callsign}/closings/closings.html` |
| **WorldNow orgname HTML** | `https://wjla.com/weather/closings` | `{origin}/resources/ftptransfer/{callsign}/closings/*.html` (most Sinclair) |
| **TEGNA closings module** | `https://www.wfaa.com/closings` | Server-rendered `closings__error` / `closings__item` HTML |
| **Hearst closingsData** | `https://www.kmbc.com/weather/closings` | Embedded `closingsData` payload (`closings: []` / `total: 0` when empty) |
| **CBS News school-closings feed** | `https://www.cbsnews.com/baltimore/school-closings/` | XML URL in `data-school-closings-options` (NewsTicker or BLOX) |
| **Cox Arc closing-list** | `https://www.wsbtv.com/weather/school-closings/` | Server-rendered `closing-list` widget (`No results found` when empty) |
| **Arc SchoolClosings** | `https://www.9and10news.com/weather/school-closings/` | `{origin}/pf/api/v3/content/fetch/weather-school-closings` (`closing[]`; empty copy on the page when none) |

An empty feed is a **confirmed empty report**, not a parse failure:

- Gray / Allen GSync: `totalResults: 0` / empty `organizations`
- TownNews: `<File>` with no `<Closing>` rows
- Nexstar iframe: `No closings to report`
- Nexstar closings widget: placeholder copy, no list items
- NBC O&O: `Forecast: School's Open.` / empty `closings__listings` / JSON `[]`
- Scripps / FlashAlert: `There are currently no active closings or delays` / `No information reported`
- WorldNow: `There are no active records at this time` / `No Closings Reported`
- TEGNA: `No delays or closings.`
- Hearst: `No closings or delays at this time` / `closings: []`
- CBS Newsroom XML: `NUM_CLOSINGS` 0, or BLOX empty `<File>`
- Cox: `closing-list` + `No results found`
- Arc SchoolClosings: `No active school closings at this time` / JSON with no `closing` rows

Other stations in those same families can work by pasting that station's closings URL. This is still a handful of adapters, not a universal HTML scraper.

Ownership group is **not** the parser. Sinclair KATU is FlashAlert; Sinclair WJLA/KOMO are WorldNow HTML; Allen Media WTHI is Gray GSync; FOX4 Kansas City is Nexstar, not FOX O&O WorldNow.

See [RESEARCH.md](RESEARCH.md) for the family-by-family investigation log.

## How parsing works

1. Read `school` and `closingsurl` from `ctx.inputs`.
2. `http.get` the configured URL.
3. Detect the closings technology family (GSync, BLOX XML, Nexstar/PSG, NBC, FlashAlert, WorldNow, TEGNA, Hearst, CBS Newsroom XML, Cox closing-list, Arc SchoolClosings).
4. Fetch that family's small JSON, XML, iframe, or use the server-rendered listing already on the page.
5. Normalize each row to `{name, status, detail}`.
6. If a school name was entered and it matches a reported listing, that row is moved first.
7. Draw the board, then up to five still frames.

Statuses are folded when practical: `CLOSED`, `2 HR DELAY`, `1 HR DELAY`, `OPENING LATE`, `EARLY DISMISSAL`, `REMOTE LEARNING`, `CANCELLED`.

A school name on the header is context only. Matching is case-insensitive and uses the listing name (`WABASH` matches `WABASH CITY SCHOOLS`). Exact names sort ahead of prefixes, then substring matches. Other reported closings still follow. If the name is not on the source list, the order is unchanged and no extra row is invented.

## Refresh and caching

- Panel **refresh**: 300 seconds
- HTTP **TTL**: 300 seconds

GDN caps uncached `http.get` calls at 8 per render. The usual path is **2 requests** (the webpage, then that family's feed), cached for five minutes. Four States skips the blocked HTML page and uses WordPress JSON instead. Direct JSON or XML URLs use **1 request**. GDN does not follow HTTP redirects.

## Errors and empty states

The panel always draws something:

| Situation | Panel |
|-----------|--------|
| Missing URL | `SET CLOSINGS` / `WEBSITE URL` |
| Network down / timeout / non-200 | `SOURCE` / `UNAVAILABLE` |
| Page is not a supported closings source | `SOURCE NOT` / `SUPPORTED` |
| Supported source with zero reported rows | `NO REPORTED` / `CLOSINGS` |
| Supported source whose rows cannot be read | `SOURCE NOT` / `SUPPORTED` (not “no closings”) |

The empty state does **not** say everything is open. It only says the configured source has **no reported closings**.

```powershell
gdn render apps/local-closings --input "school=WABASH CITY SCHOOLS"
gdn render apps/local-closings --input "closingsurl=https://www.21alivenews.com/weather/closings/"
gdn render apps/local-closings --input "closingsurl="
gdn validate apps/local-closings
```

## Current technical limitations

- Fonts are **uppercase only**. Frames are **still images** (no scroll/animation); the next refresh shows new data.
- Outbound `http.get` times out at 4 seconds, does not follow redirects, and truncates bodies over 2 MB.
- Only the documented closings families are parsed. Other websites show **SOURCE NOT SUPPORTED**. This app cannot read an arbitrary webpage.
- The app cannot discover a closings website from a school name and cannot remember a mapping.
- At most **five** closings are shown. Matching looks through up to 40 parsed listings so a later match can still surface first.
- Organization JSON field names vary; the parser tries several keys (`name`, `organizationName`, `status`, `completeStatus`, and NewsTicker XML tags). A future Gray schema change can break row reading without breaking empty-list detection.
- This is **not** an official 21Alive, Gray Media, or emergency-alert application.

## Adding another TV source later

Keep the same pipeline and add a detector + parser:

1. `fetch_source()` — decide which adapter owns the URL.
2. `parse_*()` — return normalized `{name, status, detail}` rows, or an explicit empty / unsupported / unavailable kind.
3. `normalize_status()` — reuse the shared status folder.
4. Drawing stays unchanged.

Good next adapters, if they expose a small public JSON/XML feed:

- Other stations that already share a family above
- Emergency Closing Center (CBS Chicago) **only** if a non-JS JSON/XML endpoint appears
- Newsroom Solutions public listings **only** if a non-login feed appears

Do not attempt a universal HTML parser in GDN Starlark.

## Informational disclaimer

Local Closings is informational. It reports what the configured public source published. It is not an emergency alert system, not a substitute for the station's own closings page, and not a guarantee that a school, business, or road is open or closed.

## Originality and attribution

The page structure and Starlark drawing code were created for this app. Closing facts come from the configured public source (Gray GSync / NewsTicker, TownNews BLOX XML, Nexstar WordPress / PSG, NBC O&O, Scripps / FlashAlert, WorldNow HTML, TEGNA, Hearst, CBS Newsroom XML, Cox closing-list, or Arc SchoolClosings). README screenshots show the closed / delay layout.

Built for the [Glance Developer Network](https://github.com/glance-led-dev/glance-dev-network).
