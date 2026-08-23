# Local AQI

Live US air quality and health guidance for a zip code, from the EPA.

Pages: `now`, `health`

## Setting it up

1. Request a free key at **<https://docs.airnowapi.org/account/request>**. AirNow is the EPA's own feed and approval is usually immediate.
2. Paste it into **AirNow API key**.
3. Set your **Zip code**.
4. Optionally set a **City label** — leave it blank to use the reporting area name AirNow returns.

## Settings

| setting | what it is |
|---|---|
| **AirNow API key** *(credential)* | Free key from https://docs.airnowapi.org/account/request (AirNow is the EPA feed; approval is usually immediate). |
| **Zip code** | A US zip code. |
| **City label (optional)** | Leave blank to use the reporting area AirNow returns. |

## Notes

- AQI is reported per *reporting area*, which can be a whole metro rather than your exact street.
- US coverage only. AirNow does not cover other countries.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
