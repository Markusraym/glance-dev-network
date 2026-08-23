# Bird Sightings

Notable birds reported near you in the last week.

Ships as a pair: **`ebird-nearby`** (64x32) and **`ebird-nearby-scroll`** (192x32). Same app, different panel width — set
whichever one matches your hardware; the settings below are identical.

## Setting it up

1. Create a free eBird account at **<https://ebird.org>** if you do not have one — it is the Cornell Lab's birding database.
2. Sign in, then request a token at **<https://ebird.org/api/keygen>**. It is issued immediately.
3. Paste it into **eBird API token**.
4. Pick your **Region**. Sightings are reported per US state.

## Settings

| setting | what it is |
|---|---|
| **eBird API token** *(credential)* | Free token, takes a minute: https://ebird.org/api/keygen (sign in with a free eBird account first). Or enter DEMO to preview with sample data. |
| **Region** | Sightings are reported for this state. |

## Notes

- Type `DEMO` into the token field to see the app running on sample data before you sign up.
- "Notable" is eBird's own classification: rare for the region, or out of season. A common sparrow will not appear.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
