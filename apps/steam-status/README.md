# Steam Friends

Which of your friends are online and what they are playing.

Ships as a pair: **`steam-status`** (64x32) and **`steam-status-scroll`** (192x32). Same app, different panel width — set
whichever one matches your hardware; the settings below are identical.

## Setting it up

1. You need a Steam account with a **verified email address** — Valve will not issue a key otherwise.
2. Get the key at **<https://steamcommunity.com/dev/apikey>**.
3. Paste it into **Steam Web API key**.
4. Find your 17-digit **SteamID64** — <https://steamid.io> converts a profile URL into one — and paste it into **Your SteamID64**.

## Settings

| setting | what it is |
|---|---|
| **Steam Web API key** *(credential)* | Free from https://steamcommunity.com/dev/apikey (needs a Steam account with a verified email). |
| **Your SteamID64** | 17-digit id. Find it with steamid.io. |

## Notes

- Your friends list must be public to the key's owner, and individual friends who set their profile to private will not appear.
- SteamID64 is the long numeric one, not your display name or vanity URL.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
