# Compact Stocks

Live quotes for up to five tickers.

## Setting it up

1. Get a free key at **<https://twelvedata.com/apikey>** — the free tier allows 800 calls a day.
2. Paste it into **Twelve Data API key**.
3. Put up to five tickers in **Symbols**, comma separated, e.g. `AAPL,MSFT,NVDA,TSLA,AMZN`.

## Settings

| setting | what it is |
|---|---|
| **Twelve Data API key** *(credential)* | Free key from https://twelvedata.com/apikey -- 800 calls a day on the free tier. |
| **Symbols** | Up to 5 tickers, comma separated. |

## Notes

- 800 calls a day is plenty for one panel, but it is shared across every app using the same key.
- This is a port of the tidbyt/community "Compact Stocks" app, translated and then hand-finished.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
