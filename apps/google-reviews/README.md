# Google Reviews

Your business's Google rating on the panel: the score, five stars filled to
the exact rating, the review count, and your business name. No API key.

## Setup

Type your **business name plus city and state** into the Business input —
the default shows the shape: `Le Tub Saloon Hollywood FL`. The app resolves
it to your Google listing the same way the Maps search box would and shows
that listing's rating and review count.

**Check the name on the panel is your business.** Google matches fuzzily,
and for chains or common names the top match may be a different location —
the app flags `CHECK MATCH` when the name it found shares no word with what
you typed. If it matches the wrong place, add your street to the input, or
use your exact **Place ID** (`ChIJ...`) from Google's Place ID Finder:
<https://developers.google.com/maps/documentation/javascript/examples/places-placeid-finder>
