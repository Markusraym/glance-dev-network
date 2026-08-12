# Steam Players

Steam Players is a Glance Scroll Games app by reyos86. It shows live Steam player counts for a favorites list of up to four games — game name, how many are playing now, and AppID.

![Steam Players preview](preview/preview.png)

## Preview

From the GLANCE Developer Network repository:

```powershell
pip install -e .
gdn studio apps/steam-players
```

Or:

```powershell
gdn preview apps/steam-players
gdn render apps/steam-players --input "favorites=730,570"
gdn validate apps/steam-players
```

If `gdn` is not on `PATH`, use `python -m gdn.cli` instead.

## Configuration

- **Favorites** — free-text, comma-separated Steam AppIDs or short names.
  - Default: `730,570,1245620,252490` (CS2, Dota 2, Elden Ring, Rust)
  - Short names: `CS2`, `DOTA2`, `TF2`, `GTA5`, `ELDEN`, `RUST`, `PUBG`, `APEX`, `VALHEIM`, `HELLDIVERS`, `BG3`, `CYBERPUNK`, `WARFRAME`, `DESTINY2`, `ROCKETLEAGUE`, `SKYRIM`, `STARDEW`, `HADES`, `PALWORLD`
  - Find any AppID in a store URL: `store.steampowered.com/app/730/…`
  - First 4 entries get pages (`g1`–`g4`). Duplicates are skipped.

## Pages

| Page | Contents |
|------|----------|
| **g1–g4** | One favorite each: `STEAM`, `#n/total`, game name, `Nn PLAYING`, optional `ID …`. Empty slots show a tip to add more AppIDs. |

Panel size is **192×32**. Refresh is **300** seconds. Player counts cache ~3 minutes; store names cache ~24 hours.

## Data sources

Current players (no API key):

```text
https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid={id}
```

Game name (Store basic details; known titles used as fallback):

```text
https://store.steampowered.com/api/appdetails?appids={id}&filters=basic
```

## Features

- Favorites list of up to 4 games (AppIDs or short names)
- Live player counts with compact K/M formatting
- Store-backed names when available
- Offline / API failure shows `PLAYERS UNAVAILABLE` with the known game name
- Empty list tip: `ADD APPIDS IN SETTINGS`

## Errors

When Steam is unreachable, the panel still shows the game name (from cache or known list) and `PLAYERS UNAVAILABLE`. Invalid AppIDs show `APP {id}` with the same warning. It does not invent fake player counts.

## Known limitations

- Not a full SteamDB clone (no charts, price history, or review graphs)
- Max 4 favorites on the panel (extra AppIDs in the list are ignored)
- Store name lookups can be rate-limited; popular titles fall back to built-in labels
- Counts are Steam “currently playing” only (not 24h peak)

Built for the [GLANCE Developer Network](https://github.com/glance-led-dev/glance-dev-network).
