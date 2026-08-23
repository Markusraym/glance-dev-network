# Glucose Monitor

A live CGM reading, trend arrow and rolling average from your own Nightscout site.

## Setting it up

1. This reads **your** Nightscout instance — it is not a Dexcom login. You need Nightscout already running.
2. Put your site's domain in **Nightscout URL**, with no `https://` — for example `yoursite.onrender.com`.
3. In Nightscout, open **Admin Tools** and create a **read-only access token**.
4. Paste that into **Nightscout Access Token**.

## Settings

| setting | what it is |
|---|---|
| **Nightscout URL** | Your Nightscout site domain, no https:// (e.g. yoursite.onrender.com) |
| **Nightscout Access Token** *(credential)* | A read-only access token from your Nightscout Admin Tools |
| **UTC Offset (hours)** | New Mexico: -7 in winter (MST), -6 in summer (MDT). Doesn't auto-adjust for daylight saving — you'd flip this twice a year. |

## Notes

- The `https://` is omitted on purpose: settings ride a colon-separated descriptor, so a pasted URL would arrive at the app as just `https`.
- A read-only token is enough. Do not use an admin token.
- This is a convenience display, not a medical device. Treatment decisions belong with your actual CGM app.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
