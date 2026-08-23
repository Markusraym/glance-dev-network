# MBTA Tracker Classic

A live countdown board for any MBTA subway or commuter rail station.

Ships as a pair: **`mbta-tracker-classic`** (64x32) and **`mbta-tracker-scroll`** (192x32). Same app, different panel width — set
whichever one matches your hardware; the settings below are identical.

## Setting it up

1. Pick your **Station** from the dropdown. That is all that is required — the app works with no key.
2. A key is optional. Get one free at **<https://api-v3.mbta.com/register>** if you want a higher rate limit.
3. Add a key if the panel refreshes often, or if you are iterating in Studio, where the keyless limit is easy to hit.

## Settings

| setting | what it is |
|---|---|
| **Station** | Stations served by both a subway line and the Commuter Rail (Back Bay, Braintree, Forest Hills, JFK/UMass, Malden Center, North Station, Oak Grove, Porter, Quincy Center, Ruggles, South S... |
| **MBTA API Key (optional)** *(credential)* | Optional. Free key from https://api-v3.mbta.com/register . The app works keyless at a lower rate limit; add a key if this panel refreshes often or you are iterating in Studio, since the k... |

## Notes

- Stations served by **both** a subway line and the Commuter Rail appear twice in the dropdown, once per mode — Back Bay, Braintree, Forest Hills, JFK/UMass, Malden Center, North Station, Oak Grove, Porter, Quincy Center, Ruggles and South Station.
- Boston only.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
