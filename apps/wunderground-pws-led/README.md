# Personal Weather Station (PWS) – Weather Underground

Display real-time weather from **your** Weather Underground personal weather station on a Glance LED panel.

**Version 1.0** · App ID: `wunderground-pws-led`  
**By** [SlaterDen](https://https://github.com/SlaterDen/pwswu)

---

## App Settings

| Setting | Required | Description |
|--------|----------|-------------|
| **Station ID** | Yes | Your WU station ID (example: `KOKEDMON123`) |
| **API Key** | Yes | WU API key (Glance encrypted api-key field) |
| **Temperature Unit** | Yes | **Fahrenheit** (°F, inHg, mph, in) or **Celsius** (°C, mb, km/h, mm) |
| **Location Label** | No | Shown on the main page (e.g. `Home`). Blank = station city/neighborhood |

---

## How to Get Your API Key

1. Sign in at:  
   (https://www.wunderground.com/member/api-keys)
2. Open **API Keys** for your devices.
3. **Generate**, copy the key, and paste it into the Glance app **API Key** setting.

You need a station that reports to Weather Underground. PWS API keys are free for compatible device owners.

---

## Pages

| Page | Contents |
|------|----------|
| **Main** | Condition header, temperature, feels-like, condition icon, location |
| **Wind** | Direction in header; speed and gust |
| **Rain** | Today’s total and current rate (or “no rain today”) |
| **More** | Pressure, humidity, dewpoint |
| **Alerts** | NWS alerts for the station location (U.S.). Priority single layout for Tornado / Severe T-Storm **warnings**. Up to two alerts in list view |

---

## Data Sources

| Source | Used for |
|--------|----------|
| **Weather Underground PWS API** (`api.weather.com`) | Current observations; history for pressure trend and recent rain |
| **National Weather Service** (`api.weather.gov`) | Active alerts near the station coordinates |

Not affiliated with Weather Underground, The Weather Company, or the NWS. Data remains the property of those providers. WU use is subject to their terms and rate limits.

---

## Errors & Troubleshooting

| Display | Likely cause | What to try |
|---------|--------------|-------------|
| **PWS ERROR** / Enter API Key + Station ID | Missing or invalid settings | Check Station ID and API Key |
| No / stale data | Station offline or WU delay | Confirm the station is uploading on WU |
| **NO RAIN TODAY** | No precip recorded today | Normal when dry |
| **NO ALERTS…** | No active NWS alerts | Normal |
| Alerts limited outside the U.S. | NWS is U.S.-focused | Expected for many non-U.S. stations |

---

## Notes

- Panel size: **64×32** (single module).
- Default refresh: **120** seconds (manifest); your layout may also control timing.
- Free WU PWS keys are typically limited to about **1,500 calls/day** and **30 calls/minute**. This app uses request TTLs where possible.
- Condition icons and labels use station sensors (and NWS **warnings** when relevant). A single PWS is a point measurement—use official NWS sources for life-threatening weather.
- Companion wide layout: **192×32** app (`wunderground-pws-scroll` or your wide app id) if you use a longer panel.

---

## Credits

**SlaterDen** · Built for the [Glance Developer Network](https://glance-led.dev).