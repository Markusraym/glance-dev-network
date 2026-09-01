# Google Reviews

Your business's Google rating on the panel: the score, five stars filled to
the exact rating, the review count, and your business name. A second page
rotates through your newest review texts.

## Setup

### 1. Place ID (required)

The **Place ID** identifies your business on Google Maps (it looks like
`ChIJN1t_tDeuEmsRUsoyG83frY4`).

Find yours with Google's Place ID Finder:
<https://developers.google.com/maps/documentation/javascript/examples/places-placeid-finder>
— search your business name and copy the ID it shows.

No API key is needed for the rating page: the app reads the same public
rating + review count Google shows on the map embed.

### 2. API key (optional — review texts only)

The **latest reviews** page (author, stars, review text) uses the official
Places API, which needs a key:

1. Go to <https://console.cloud.google.com/>, create (or pick) a project.
2. Enable **Places API (New)**.
3. Create an API key under *APIs & Services → Credentials*.

Google's free monthly credit comfortably covers this app's usage (one
request per half hour). Without a key, the reviews page shows a note and
the rating page works normally.
