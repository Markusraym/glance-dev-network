# ISS Next Sighting

When and where to look up for the next visible pass of the Space Station.

Pages: `intro`, `sighting`, `path`, `sighting2`, `path2`, `sighting3`, `path3`, `crew`

## Setting it up

1. Enter a US **Zip code**. It is used to look up your latitude and longitude.
2. Create a free account at **<https://www.n2yo.com>**.
3. Go to **Account → API Key** and copy it.
4. Paste it into **N2YO API key**.

## Settings

| setting | what it is |
|---|---|
| **Zip code** | A US zip code - used to look up your latitude/longitude. |
| **N2YO API key** *(credential)* | Free key from n2yo.com - sign up, then Account > API Key. |

## Notes

- Only naked-eye-visible passes are shown — the station has to be sunlit while your sky is dark, which is why some days have none.
- The crew page comes from a separate open feed and needs no key.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
