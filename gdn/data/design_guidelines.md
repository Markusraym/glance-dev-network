# GDN design guidelines

How Glance apps should *look* — Glance's design requirements, plus the
conventions measured from the shipped catalog. `glance://reference/authoring`
covers the mechanics (API, manifest, hard rules); this document covers the
design. When a rule names an app, that app is the reference implementation.

**Precedence.** These guidelines are defaults for the AI, not law for the
human. A human developer may override any of them case by case — their design
intent always wins. What they exist to prevent is the opposite failure: a human
leans on AI, the AI leans on a template, and every app comes out looking the
same. Follow the requirements here, but never let them substitute for the
human's own design.

## 1. Start with the human's design

**Before writing any code, ask the human how they want the app to look.**
Request a layout — a drawing, a sketch, a photo of a napkin, or a zone-by-zone
description in words. Collect at least:

- **The layout** — what sits where on the strip: left/center/right, top/bottom.
- **The hero** — the one piece of content the app exists to show, and how big
  it should feel.
- **The pixel art** — what image, if any, carries the app's identity, and what
  it should replace in text.
- **Palette and mood** — brand colors, an accent, quiet or loud.
- **Target widths** — 64x32 static, larger-than-64 scroll, or both.

**Then iterate on the design before wiring the data.** Render a mockup of the
human's layout with placeholder content, show it, and adjust until they approve
the look. Only then build the data path behind it. The human designs; the AI
does the tedious coding.

**The goal is apps that look the best — and materially different from every
other app.** Two apps that both follow this document should still be visually
distinct, because their designs came from two different humans. If a proposed
design would be indistinguishable from an existing GDN app, say so and push for
what makes this one its own.

**And when the content resists a clean layout, hand it back.** Some data
genuinely doesn't fit these rules — three labelled numbers plus identity art on
64x32 has no obviously right answer. When the AI can't lay it out without
breaking the rules or gutting the design, it says so and gives the human the
trade-offs to decide, instead of shipping a forced compromise.

## 2. The canvas, and where content is allowed to live

Every panel is **32 px tall**. Width picks the design problem — and the space
rules are *opposite* per device:

| size | used on | space rule |
|---|---|---|
| 64x32 | all end products | **Maximize the space.** With this few pixels, minimize no-content areas — every pixel should be earning its place. |
| >64x32 (128/192/384) | SCROLL | **Respect a safe zone.** Keep content inside roughly x 10–182 on a 192-wide app, with 6–10 px of padding at the left and right edges. |

**The #1 scroll rule: design for the sequence.** On SCROLL the display is a
stream moving right to left: an unknown app plays before yours, another after,
and your own pages rotate in between based on the end user's inputs. Scroll
hardware comes in threes — **Studio 192x32, Pro 384x32, Premier 640x32** — so
on the wider panels your app is on the glass *at the same time* as one or two
neighbors. An app with content at pixel 0 or 191 visually merges with whatever
plays around it. Design the app to read as its own unit: edge padding, a
contained/boxed trailing zone, or a closed frame — and always preview it *in
sequence*, not alone. The padding is **per app, not per page** — pages inside
one app can sit closer together, but the app's outer edges need the buffer.

Scroll apps have two placement options: **edge padding or centering**. Not
everything should be centered, but lean on the center of the canvas rather than
hard-justifying content against the left and right sides. Reduce wasted space
*within* the safe zone too — a scroll app that parks a small cluster of content
in one corner of 192x32 is wasting the panel.

**These space rules bind the AI's defaults, not the human.** A human's own
design may run elements to the edge deliberately (some shipped scroll apps draw
a thin 2 px accent stripe at the far-left edge as a frame, for example). When
the AI is laying out a scroll app on its own, it keeps content — text, data,
pixel art — inside the safe zone.

**The one adaptive branch is `if c.width >= 128:`.** The catalog treats 64 as
"narrow" and everything else as "wide"; the layout linter understands exactly
this shape. **Write different copy for each width, never clipped copy**
(`"MARKET HOLIDAY"` → `"HOLIDAY"`), and drop elements entirely on 64 rather
than squeezing them. 55 of 59 classic/scroll pairs ship a byte-identical
`app.star` — write the width branch once and both builds come free.

## 3. Layout grammar

### Context switching: every app must identify itself

It is not obvious what an app is ~85% of the time just by seeing its data.
Because apps rotate in a shared stream, **add a splash/intro page** to create a
break from the preceding app — or, if a splash page isn't warranted, make sure
the app carries a **pixel-art identity or a title** so a viewer can
context-switch into its data feed:

- Time doesn't need a title or splash — it's a clock, we get it.
- Snowfall likely needs a title, but with pixel art of snow falling a splash
  page isn't required.
- The Minecraft app opens on the Minecraft logo.

**Location-based apps always show the location on the image.** If the input is
a zip code and there's no location API, display the zip itself.

### Classic panels (64 / 128)

Vertical bands, measured from the catalog: **header y 0–7** (filled strip with
centered `5x7`/`4x5` text, or a `4x5` eyebrow in dim gray), **hero y 8–13**
(`16x20` wide / `10x16` narrow), **second row y 17–22**, **footnote y 23–27**.
Margins 2–6 px; a left icon at `x = 1`, vertically centered; text next to a
24 px icon starts at x 28. One 1 px hairline under the header is the whole grid.

Lists: divide the height evenly (`lh = c.height // n`, 3 rows on 64, 4 on
wide). Row anatomy is left-label / right-value, and the **right side is
measured first** — draw the value, compute what's left, then fit/clip the label
into it. Nothing in the API clips; this ordering is what prevents collisions.

### SCROLL — the house kit

The modern scroll apps share a page grammar (github-pulse-scroll lines 1–237 is
the canonical copy): an accent **rail** wearing the app's state color, a **chip
row** (state-carrying `tab()` chip, meta right-aligned), and a **content band**
(y 8–31) split into named zones by `vline`s. "An amber REVIEW chip above a
green ALL CAUGHT UP is the page contradicting itself" — compute state first,
then dress the chrome in it. List bullets are a 2x2 colored square; reflow
columns by item count (2 columns while ≤ 6 items, 3 after).

### Spacing rules (hard requirements)

- **Nothing draws off the canvas.** The renderer clips silently at the
  borders — a draw one pixel past the edge just loses that column, with no
  error. Any element near an edge is placed by its *measured* width (or
  right-aligned against the edge), never at a hand-picked x, and the
  worst-case string is rendered and checked at both edges.
- **1 px minimum buffer between text and the next asset** — line, polygon,
  pixel art, anything.
- **1 px minimum between vertically stacked text rows.** If two rows can't keep
  the gap, reduce the font size until they fit nicely — never let rows touch.
- **Text on a filled shape is centered both ways.** Black text on a pill: the
  pill is centered vertically and horizontally on the text, high contrast, even
  padding all around.

### More content than fits — three mechanisms, none of them animation

1. **Pages** — `pages: [today, tasks]`, one function per name; the panel
   rotates them. 1–3 typical; the 8-`http.get` budget per render is the ceiling.
2. **Frames** — time-multiplex inside one page:
   `frame = (ctx.now.unix // 60) % 3` with `refresh: 60`, plus a hidden
   `_debugframe` input for previewing.
3. **Truncate with an explicit overflow count** — show 3, then `"+N MORE"`
   right-aligned in `4x5`.

## 4. Typography

**The more important the data, the larger the font.** Most SCROLL users view
from 10–30 feet; small text presents *really* small at that range. Size the
hierarchy by importance, and let the hero dominate. Fonts are bitmap,
**UPPERCASE ONLY** (`.upper()` everything; `5x5` is the sole font with a full
lowercase set). Roles, by catalog usage:

| role | wide (128+) | narrow (64) |
|---|---|---|
| eyebrow / label / meta / chip | `4x5` (the workhorse) | `4x5` |
| body & list rows | `5x7` (or `4x7`) | `4x5` |
| sub-head | `6x8` | `5x7` |
| hero value (one per page) | `16x20` / `16x24` | `10x16` |
| footnote | `picopixel` / `4x5` | `picopixel` |

**Design for the worst case, not the average.** The longest possible string is
the design point — if the app shows MLB teams, "WASHINGTON" is the string that
must fit, or there must be a plan: truncate deliberately, or switch to an
abbreviation that fits the space.

**Fit with a ladder, then clip by hand.** `c.text_fit()` picks the biggest font
that fits — but when even the smallest overflows it **still draws** (nothing in
the API clips). The catalog's answer, in 80 apps, is
`_fit_clip(c, text, fonts, maxw)`: pick the largest that fits, then hard-clip.
Canonical ladders:

```python
NODATA_FONTS = ["10x16", "6x8", "5x7", "4x5"]   # error titles, 40 apps verbatim
["6x8", "5x7", "4x5"]                            # narrow headline
["10x16", "6x8", "5x7"]                          # wide headline
```

Clip at a word boundary when the tail is a whole word, but not when that costs
more than ~30% of the string. When a wrapped block drops lines, append `".."`
so the cut reads as deliberate.

**No overlapping text, ever** — text may only sit on other drawn pixels when
`text_stroke` (drawTextWithStroke) separates it from what's behind. Measure
before committing (`c.text_width` / the `measure_text` tool); a right-aligned
draw with no bound grows leftward into its neighbor the day a longer string
appears.

Font traps (all silent): `3x4` has no space glyph ("HARD FREEZE" →
HARDFREEZE — single words only); `8x12`'s `-` glyph is a solid block (skip it
in ladders for hyphenated strings); Starlark has no font metrics call, so carry
a height table (`FONTH = {"16x20": 20, "10x16": 16, "6x8": 8, "5x7": 7,
"4x5": 5}`).

## 5. Color & contrast

**High contrast is a requirement, not a taste.** These are LEDs viewed across a
room — high-contrast text against the background is what pulls information off
the screen and into the eye.

- **Limit full-colored backgrounds. Black backgrounds are very good** — they
  are the cheapest high contrast there is. On scroll apps especially, avoid
  full-color background images when they aren't necessary (they also fight the
  apps before and after in the rotation).
- **If a full-colored background is used, stroke the text — black by
  default.** `c.text_stroke()` (drawTextWithStroke) draws a border around
  every glyph. When the goal is contrast on a colored background, black is
  the stroke the AI reaches for (and the API's default): it restores the
  black-background contrast locally around each letter. But `stroke=` is a
  general parameter, not a contrast-only tool — a colored stroke as a design
  choice (white text with a blue outline, say) is fully supported, and the
  human's call. Give pixel art a creative outline for the same separation.
  The catalog agrees on the default: the only shipped apps using it are
  exactly the full-background ones (sun-arc, rain-radar).

Semantics the catalog agrees on:

- **White is the resting color for live numbers** — "which leaves amber and red
  free to mean something the moment they appear" (citi-bike). Gray
  (`gray`/`#6E7A94`) for labels.
- **Green = up/open/ok · amber = attention · red = alarm.** "Red is the only
  state allowed to shout; everything else is built quiet enough that it can."
- **Keep brand and alarm distinct** (todoist-scroll: brand `#E44332`, overdue
  `#FF3B30` — "so brand and alarm never fight").
- **Thresholds are banded `[label, color]` pairs** from one function, so the
  color and the word can never disagree.
- **Past / present / future = full / dim / gray** — declare dim twins, or use
  `color.dim(col, pct)` for tracks and washes.

The named palette is LED-tuned (`green` is (0, 220, 70), not lime; brand
`purple` #7521F9, `skyblue` #78DCFF). Panels are RGB565 — subtle shades
collapse, so keep values punchy and separated. Near-black tinted fills and
vertical near-black gradients (`#0A1220`→`#1E3350`) are the catalog's
compromise between a mood and a black ground — never a bright fill. On filled
chips/rows, compute contrast: flip text to black when the fill's brightness
passes ~150.

## 6. Pixel art & data labels

**Prioritize graphics over text.** Pixel art is the panel's native language;
when a picture and a word compete for the same pixels, the picture wins and the
text supports it. Never delete a working graphic to make room for a label —
find the layout that keeps both, or shrink the label.

### No magic numbers

**Every number gets pixel art or a data label saying what it is.** A bike-share
app with 3–4 large numbers and no labels leaves the viewer guessing — available
docks? free bikes? Temperatures always carry degrees. Units of measurement
always carry a label. A label can be a pixel-art asset instead of text, but it
must be **intuitive to a 5th grader** what the number represents on the final
app.

### Pixel art quality (requirements)

- Pixel art must **never interfere with other assets** on the screen —
  including when it *changes size*: a growing or shrinking sprite must not
  overlap anything at any of its sizes.
- Pixel art should **replace repetitive and obvious text** while adding
  context — the best apps let the picture be the label ("the word 'BIKES' is
  not on the panel — the bike is").
- Pixel art must be **pixel-perfect: no anti-aliasing, no semi-transparent
  pixels.** Draw at native resolution and scale with **nearest-neighbor
  interpolation only** (the renderer's default), so pixels stay crisp. A fully
  transparent background behind hard-edged pixels is fine — it's soft alpha
  edges and interpolation blur that are banned.

### Mechanisms, in order of preference

1. **`c.sprite()` string art with a legend** — costs no asset, recolors per
   state (one glyph, many legends; `scale = 2` for a hero).
2. **PNG assets** — declared under `assets:`, ≤ 128 KiB, drawn at the size they
   were authored: ship the same filename as a real 24x24 *and* a real 16x16
   (`sz = 24 if c.width >= 128 else 16` — the most repeated line in the
   catalog) rather than scaling one file.
3. **`c.bitmap()` 0/1 matrices** for tiny inline glyphs.

## 7. States: every app has four screens, not one

The publish-time validator renders every page with the network disabled — a
panel on a wall must say something sensible rather than going blank. Design all
four:

1. **Live** — the happy path.
2. **No data / error** — the shared card. Classic form (`nodata(c, title,
   sub)`, 41 apps byte-identical): background `#0B0C12`, centered amber
   `#E8B04A` title (NODATA_FONTS ladder), dim slate `#6A7090` sub, on bands
   that can never overlap. SCROLL form: `rail(c, OFFLINE)` + `message(c, head,
   sub)`. Copy is two short uppercase lines — a *what* and a *what to do*:
   `("NO LOCATION", "SET A ZIP")`. Name the states separately (bad key ≠
   rate-limited ≠ offline ≠ empty), and be actionable:
   `"SHORTEN NAME AND PASSWORD BY " + str(over)`.
3. **Empty — which is NOT an error.** Zero storms, zero tasks, zero trains is
   the answer people want: a green rail and a positive line (`"ALL CLEAR"`),
   never the amber card, never a blank panel.
4. **Demo — when a required key is absent.** Believable sample data, labelled
   `DEMO` on the panel, promised in the input's help text.

Degrade, don't die: a failed timezone lookup costs the offset, not the panel.
Wrap every feed read in safe accessors — "a raised host error kills the whole
render."

## 8. Data: cadence and constraints

- **API data is constrained before it is drawn.** Never display a returned
  string with a loose edge — everything that comes back from an API goes
  through the measure/fit/clip path so it cannot run off the canvas. No
  exceptions for "it's always short in practice."
- `refresh` follows the data, not the device: 60 s for clocks, 300 for transit
  and markets, 900–1800 for weather, 3600 for daily feeds.
- `ttl_seconds` on `http.get` tracks how fast each hop moves: 86400 for
  geocoding and grid lookups, down to 60 only for genuinely live feeds. Keep
  `refresh` and the main fetch's ttl in sync, and say so in a comment.
- Two-hop location is standard: zip → `api.zippopotam.us/us/<zip>` (ttl 86400)
  → lat/lon → the real feed. Send a User-Agent to NWS.
- Budget: max 8 `http.get` calls per render — size the page count to it.

## 9. Inputs

- **Free text only for genuinely free text.** If the value could be a picklist,
  it is one: dropdowns and option fields defined in the GDN source beat free
  text, because free text is where community error comes from. Free text is
  right when the value is displayed verbatim or passed to an API (a zip, a
  station ID, a key); a backend input that *selects behavior* is a dropdown.
- **Every logic path an input combination allows must work.** "Zip code OR
  station ID" means the app handles either one being absent — or a dropdown
  first asks which the user is providing, and the free text follows. No
  combination of filled/blank inputs may break the render.
- **Every input is visibly used.** If an app takes multiple inputs and shows
  one page, the page uses them all — or the app makes a page per input (never
  a random subset of the inputs' pages).
- Input keys are letters+digits only (`apikey`, never `api_key`); API keys must
  be `app_input_type: api-key` (encrypted) with a folder `README.md` saying
  where to get one. Defaults containing `:` are truncated; date pickers arrive
  as `"2026-08-14T01"` — parse digits. Optional blank-default inputs are read
  as `ctx.inputs.get("key", fallback)`. Reuse the shared 52-zone `timezone`
  dropdown and the `zip` input where they fit.

## 10. Naming, category & submission

- **App names are descriptive of what the app actually is, and mutually
  exclusive** — against every app in *all of Glance*, not just GDN. "Custom
  Sports Schedule" that is really a Scottish football schedule is named
  *Scottish Football Schedule*.
- **No "SCROLL" or "LED" in app names** — apps are potentially shared across
  the whole platform, so the device name doesn't belong in the app name.
  (Existing classic/scroll pairs use a " (Scroll)" suffix in `name:` to tell
  the builds apart — leave those as they are; retiring the suffix means
  indexing the catalog on name + size, which is tracked separately. This rule
  is about an app's own title: don't name a new app after the device it runs
  on.)
- **Every app lands in a real category** — or a new category is requested.
  *Other* is a catch-all, not a good landing place.

```yaml
gdn: 1
id: market-hours          # lowercase-hyphen, equals the folder name
name: Market Hours        # descriptive, unique across Glance, no device names
category: Finance         # a real category - Other is a last resort
width: 64                 # 64 / 128 / 192 / 384 - height always 32
refresh: 300
pages: [bell]             # one def per name; 1-3 typical
```

## 11. Comment culture

Non-obvious layout numbers carry a comment naming the collision or misread they
fix, with the offending string and its measured width: "'TROP STORM' is 107px
at 10x16, so it started at x=79 and the two drew through each other for 41px."
The best apps open with a `# DESIGN.` paragraph stating the visual thesis —
which, under these guidelines, is the human's design brief — before any code.
Write both.

## 12. Pre-flight checklist

All apps are tested for edge cases and adjusted for them before submission:

- [ ] The human's layout was collected first, mocked up, and approved before
      the data path was built.
- [ ] The design is materially different from existing GDN apps — not a
      template fill-in.
- [ ] One hero per page, sized for a 10–30 ft viewing distance; everything else
      visibly smaller and quieter.
- [ ] 64: space maximized. Scroll: content inside the safe zone (6–10 px edge
      padding, per app), centered or padded — never flush to pixel 0 / 191.
- [ ] Scroll: previewed *in sequence* — with a neighbor app ahead and behind —
      to check nothing merges at the seams.
- [ ] Worst-case strings are the design point ("WASHINGTON", not "METS") —
      fit, truncate deliberately, or abbreviate.
- [ ] Every string bounded: measured, laddered, hard-clipped; API returns
      constrained before drawing; 1 px buffers around text, horizontal and
      vertical.
- [ ] Nothing draws off-canvas — edge placements are measured or
      right-aligned, worst cases checked at both edges (the renderer clips
      silently).
- [ ] No overlapping pixels without `text_stroke`; changing pixel art overlaps
      nothing at any size.
- [ ] High contrast throughout; black or near-black ground; stroked text on any
      filled background.
- [ ] No magic numbers — every value has a label or intuitive pixel art; temps
      have degrees; location apps show the location.
- [ ] The app identifies itself: splash page, title, or unmistakable pixel art.
- [ ] All four screens designed: live, error (actionable two-liner), empty
      (positive all-clear), demo (labelled).
- [ ] Inputs: picklists over free text; every logic path works; every input
      visibly used; every declared page shown.
- [ ] Name is descriptive, unique across Glance, no SCROLL/LED; category is
      real.
- [ ] Rendered and *looked at* — including `simulate_offline` and a nonsense
      input — before calling it done.
