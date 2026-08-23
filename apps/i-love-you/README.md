# I Love You

A message from an API you build yourself.

## Setting it up

1. **There is no signup link for this one, because the API is yours.** The app fetches a message from a URL you host and displays it.
2. Build an endpoint that returns your message, and accepts the key as a query parameter named `apiKey`.
3. Put the endpoint in **API URL** and the key in **API Key**.
4. If your endpoint needs no key, put any value in the key field.

## Settings

| setting | what it is |
|---|---|
| **API URL** | — |
| **API Key** *(credential)* | The key for YOUR api, sent as ?apiKey= to the URL above. There is no signup link because the api is the one you build -- if yours needs no key, put any value here. |

## Notes

- Because the key is sent as `?apiKey=`, the endpoint must accept it that way.
- The URL is a plain setting, so it cannot contain a colon beyond the scheme — see the note about the render descriptor in CONTRIBUTING.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
