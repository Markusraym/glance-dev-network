# Horoscope

Horoscope is a Glance Scroll Lifestyle app by reyos86. It shows a one-frame daily vibe for a configured zodiac sign: original pixel glyph, sign name, `TODAY`, and a short punchline from the day’s reading (Glance flips apps ~every 3 seconds, so this stays glanceable).

![Horoscope preview](preview/preview.png)

## Preview

From the GLANCE Developer Network repository:

```powershell
pip install -e .
gdn studio apps/horoscope
```

Or:

```powershell
gdn preview apps/horoscope
gdn render apps/horoscope --input "zodiacsign=leo"
gdn validate apps/horoscope
```

If `gdn` is not on `PATH`, use `python -m gdn.cli` instead.

## Configuration

- **Zodiac sign** — dropdown: `aries`, `taurus`, `gemini`, `cancer`, `leo`, `virgo`, `libra`, `scorpio`, `sagittarius`, `capricorn`, `aquarius`, `pisces` (default `aries`).

## Pages

| Page | Contents |
|------|----------|
| **main** | Zodiac glyph, sign name, `TODAY`, and the full first sentence of the daily reading. |

Panel size is **192×32**. Refresh is **3600** seconds. API responses are cached with a **6-hour** HTTP TTL.

## Data source

[Free Horoscope API](https://freehoroscopeapi.com/) daily endpoint:

```text
https://freehoroscopeapi.com/api/v1/get-horoscope/daily?sign={sign}
```

No API key. GDN fetches server-side (browser CORS does not apply). A `User-Agent` header is required — bare clients can receive HTTP 403.

The full API essay is shortened to an opening punchline for LED readability.

## Features

- All 12 zodiac signs via Glance dropdown settings
- One-frame daily vibe (readable in a ~3s playlist flip)
- Unique bright glyph art per sign
- Graceful offline / API failure screen (`HOROSCOPE` / `UNAVAILABLE`)

## Assets

Each sign has a lowercase PNG in `assets/` (`aries.png` … `pisces.png`), drawn with `c.image`. Icons keep classic glyph shapes, scaled and recolored with a unique bright palette per sign.

## Errors

When the API is down or returns empty data, the panel shows the sign name plus `HOROSCOPE` / `UNAVAILABLE` (or `NO DATA`). It does not invent fake readings.

## Known limitations

- Depends on a third-party free API (availability and wording can change)
- Shows a punchline, not the full daily essay
- Daily only in this milestone

Built for the [GLANCE Developer Network](https://github.com/glance-led-dev/glance-dev-network).
