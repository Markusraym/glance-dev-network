# Now Playing

The top five films in theatres now.

Pages: `movie_1`, `movie_2`, `movie_3`, `movie_4`, `movie_5`

## Setting it up

1. Create a free account at **<https://www.themoviedb.org/signup>**.
2. Go to **<https://www.themoviedb.org/settings/api>** and request an API key. Personal use is approved immediately.
3. Paste it into **TMDB API key**.
4. Pick your **Region** so the listings match your country.

## Settings

| setting | what it is |
|---|---|
| **TMDB API key** *(credential)* | Free key from https://www.themoviedb.org/settings/api (create a free account at https://www.themoviedb.org/signup first). Leave blank to show the bundled sample. |
| **Region** | — |

## Notes

- Leave the key blank to see the app running on a bundled sample.
- This app uses the TMDB API but is not endorsed or certified by TMDB.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
