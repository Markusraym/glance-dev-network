# Writing a GDN app

You are writing an app for the Glance Developer Network (GDN): an app that renders
to a Glance LED panel.

The panel is always **32 pixels tall**. Each panel module is 64 pixels wide and
panels daisy-chain up to 384 pixels wide; for best performance keep images to
192x32 or smaller and split content across multiple pages.

An app is a FOLDER with two files:

    manifest.yaml  - settings: id, name, width, height, refresh (seconds),
                     pages: [list of screen names], and inputs (the user's form).
    app.star       - Starlark (Python-like) code. Define ONE function per page:
                     def <page>(c, ctx): ...  It DRAWS a picture; it never returns
                     anything. c = the canvas, ctx.inputs = the user's values,
                     ctx.now = the current time (UTC).

Coordinates: (0,0) is top-left, x grows right, y grows down. For text and images,
(x, y) is the TOP-LEFT corner. Circles/dots center on their coordinates.

## Drawing (`c.*`)

    fill(color) / clear() ; pixel(x,y,color) ; rect(x0,y0,x1,y1,fill=,outline=)
    line(x0,y0,x1,y1,color) ; text(s,x,y,font="5x7",color="white",align="left")
    text_stroke(s,x,y,font,color,stroke="black",thickness=1,align)
    image("file.png",x,y,w=,h=) ; bitmap([[0,1,...],...],x,y,color)

`text_stroke` draws an outline around every glyph (the panel's
`drawTextWithStroke`). Use it whenever text sits on a filled or colored
background — black stroke by default for contrast; a colored `stroke=` is a
design choice the human may ask for.

Helpers (composites — prefer these):

    circle, fill_circle, round_rect, hline, vline, gradient_rect,
    text_center, text_right, text_wrapped, text_fit, progress_bar, sparkline,
    bars, badge, trend_arrow, icon("sun"), sprite, header, kv, stat, gauge,
    status_dot, table, scoreboard, grid, color.dim

Colors: names (`"green"`, `"amber"`, `"red"`, `"white"`, …) or hex (`"#00FF00"`).
Call `list_colors` for the full table.

Fonts: `"4x5"`, `"5x7"`, `"6x8"`, `"7x12"`, `"16x24"`, and others. Call
`list_fonts` for the full table with pixel heights, and `measure_text` to check a
string fits before you commit to a font. The `_outline` faces (`"10x15_outline"`,
`"10x16_outline"`) carry their own border in the glyphs — a hero face for text
on a filled background, no `text_stroke` needed.

## Hard rules

These cause silent failures or validation errors. They are not style preferences.

- **Fonts are UPPERCASE ONLY.** Call `.upper()` on any text, or nothing draws.
- **Frames are STILL IMAGES.** Don't animate or scroll; the panel re-renders on the
  manifest's `refresh` timer, so let the next refresh show new data.
- **Draw immediately with `c.*`.** There is no widget tree and you never return
  anything.
- **Lay things out by hand.** The panel is only 32px tall, so keep text short.
- **`http.get` returns a DICT you read with SUBSCRIPTS.**
  `http.get(url, headers={}, params={}, ttl_seconds=300)` →
  `resp["status_code"]`, `resp["json"]`, `resp["body"]`. NOT `resp.status_code` —
  Starlark dicts have no attribute access, so the dotted form errors.
  **ALWAYS check `resp["status_code"] == 200` before reading `resp["json"]`.**
- **Read inputs with `ctx.inputs.get("key", fallback)`.** Declare each input in the
  manifest with `app_input_type`: `free-text`, `api-key`, `dropdown`, `checkbox`,
  `date`, `date-past`, `color`, or `selection`.
- **API keys MUST use `app_input_type: api-key`**, never `free-text`. Only
  `api-key` inputs are stored encrypted. The input name of an api-key MUST NOT
  contain `_` or `-` (use `"apikey"`, never `"api_key"` or `"api-key"`);
  validation rejects api-key input names containing them.

## A panel on a wall must never show a crash

Any app that fetches data needs a designed answer for the failure cases: the API
is down, the response is empty, the user typed a ZIP that doesn't exist. Draw
something sensible instead of letting the page error.

Check both paths before calling an app finished:

- `render_app` with `simulate_offline: true` — every `http.get` fails, so you see
  the no-data screen.
- `render_app` with a nonsense input (a bad ZIP, an unknown city) — you see the
  not-found screen.

`validate_app` warns if an app crashes with no network instead of falling back.

## Design with the human, not for them

Read `glance://reference/design` before laying out a page — it is the design
half of this document (layout grammar per width, font roles, color semantics,
pixel art, the four screens, and a pre-flight checklist). The rules that matter
most, because nothing errors when you break them:

- **Ask for the layout first.** Before writing code, get the human's layout (a
  sketch or a zone-by-zone description), the hero, any pixel art, the palette,
  and the target width. Mock up *their* layout with placeholder content, render
  it, iterate until they approve — then wire up the data. The guidelines are
  defaults the human may override; the app should end up materially different
  from every other GDN app.
- **64x32: use every pixel. Wider than 64 (SCROLL): keep content inside the safe
  zone** — x 10–181 on a 192-wide app, 6–10 px of padding at the app's outer
  edges — because other apps play right before and after it. Preview scroll
  apps *in sequence*, never alone.
- **One hero per page**, sized for 10–30 ft viewing. Worst-case strings are the
  design point: measure, pick the largest font that fits, hard-clip. No
  overlapping text; 1 px minimum buffer around text.
- **High contrast: black or near-black ground.** Text on any filled or colored
  background is drawn with `text_stroke` (or an `_outline` font).
- **No magic numbers** — every value has a label or intuitive pixel art; temps
  carry degrees; location apps show the location; the app identifies itself
  (title, splash page, or unmistakable pixel art).
- **Four screens**: live, error (two short lines — what, and what to do), empty
  (a positive "ALL CLEAR", not an error), demo (labelled `DEMO` when a key is
  missing).

## The loop

1. Collect the human's design brief (above). `create_app` to scaffold the
   folder, then write `manifest.yaml` and `app.star` as a mockup of *their*
   layout — placeholder content, real fonts and sizes.
2. `render_app` and **look at the image** — check for clipped text, overlapping
   elements, and colors that are unreadable on an LED panel. Show the human,
   adjust until they approve the look, then wire up the data. Fix and re-render.
   For widths over 64, Studio's **Preview your app in action** card plays the
   app between two neighbor apps — that is how it will actually be seen.
3. Render the failure screens (above).
4. `validate_app` — the same check `gdn submit` and CI run. Fix every error.
5. `write_previews` to generate the catalog images, so the folder is
   catalog-complete.
6. Walk the pre-flight checklist at the end of `glance://reference/design`.
