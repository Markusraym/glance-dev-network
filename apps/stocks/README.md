# Stock Ticker

Live price and daily change for one ticker.

## Setting it up

1. Get a free key at **<https://twelvedata.com/apikey>** — 800 calls a day on the free tier.
2. Paste it into **Twelve Data API key**.
3. Set **Ticker symbol**, e.g. `AAPL`.

## Settings

| setting | what it is |
|---|---|
| **Twelve Data API key** *(credential)* | Free key from https://twelvedata.com/apikey -- 800 calls a day on the free tier. |
| **Ticker symbol** | — |

## Notes

- Prices are delayed on the free tier. This is a glance, not a trading screen.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
