# Road Races

Your next three road races.

Pages: `race1`, `race2`, `race3`

## Setting it up

1. **This one needs a small API of your own.** RunSignup's API cannot be called directly from a panel, so you put a Cloudflare Worker in front of it.
2. Create a Cloudflare Worker that calls the RunSignup API for your account and returns your races as JSON.
3. Put its address in **Worker API URL** — the default shows the expected shape, `https://YOUR-WORKER.workers.dev/api/races`.
4. Set a shared secret in the Worker and put the same value in **Worker App Token**.

## Settings

| setting | what it is |
|---|---|
| **Worker API URL** | — |
| **Worker App Token** *(credential)* | — |

## Notes

- The Worker exists so your RunSignup credentials stay on Cloudflare rather than in a panel setting.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
