# Close Approach

NASA's Close Approach feed, on your wall.

## Setting it up

1. It already works. The app ships with NASA's shared `DEMO_KEY`, so there is nothing to do to see it run.
2. `DEMO_KEY` is rate limited **across everyone on the planet using it**, so it will fail intermittently. Your own key removes that.
3. Get one at **<https://api.nasa.gov>** — no account, just an email address, and it is issued instantly.
4. Paste it into **NASA API key**.

## Settings

| setting | what it is |
|---|---|
| **NASA API key (api.nasa.gov)** *(credential)* | Works as-is on NASA's shared DEMO_KEY, which is rate-limited across everyone using it. Your own free key is instant and lifts that: https://api.nasa.gov (no account, just an email). |

## Notes

- The distance is shown in *lunar distances* — 1.0 LD is the Earth–Moon distance, about 384,400 km. Anything under 1 LD is genuinely close.
- The hazard flag is NASA's own `is_potentially_hazardous_asteroid`, not something this app decides.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
