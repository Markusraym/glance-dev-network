# GitHub Pulse

Whether CI is green and whether a pull request is waiting on you.

Pages: `main`, `queue`, `review`

## Setting it up

1. Set **Repository** to `owner/name` — for example `glance-led-dev/glance-dev-network`.
2. A token is optional but strongly recommended. Without one GitHub allows **60 requests an hour per IP address**, shared with everyone else on the render host, so a public panel will hit the ceiling.
3. Create a **fine-grained personal access token** at **<https://github.com/settings/personal-access-tokens/new>** with read-only access. That lifts the limit to 5,000 an hour.
4. Private repositories need a token regardless.
5. Optionally set **Your GitHub username** so pull requests naming you sort first.

## Settings

| setting | what it is |
|---|---|
| **Repository** | Owner and name only, like glance-led-dev/glance-dev-network. Not the full URL -- a pasted https:// link cannot reach the app, because the colon ends the value in transit. |
| **GitHub token** *(credential)* | Optional, but recommended. Without one GitHub allows 60 requests an hour per address, shared with everyone else on this render host. A read-only fine-grained token lifts that to 5,000. Pr... |
| **Your GitHub username** | Optional. Sharpens REVIEW so pull requests naming you come first. |
| **UTC offset** | Hours from UTC, used only for the "how long ago" figures. |

## Notes

- **Do not paste a full `https://github.com/...` URL into Repository.** Settings ride a colon-separated render descriptor, so a URL arrives at the app as the word `https` and nothing else. Owner and name only.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
