# Personal Weather Station (PWS) – Weather Underground (Version 2.0)

Display real-time localized weather data on your Glance panel straight from your own Weather Underground personal weather station.

## ⚙️ App Settings

When adding this widget you will need to configure the following fields:

* **Station ID**  
  The unique ID of your hardware station on the Weather Underground dashboard (example: `KOKEDMON408`).

* **API Key**  
  Your personal API token used to securely pull data.

* **Temperature Unit**  
  Choose how temperatures and related values are displayed:
  - **Fahrenheit** – °F, inHg, mph, inches  
  - **Celsius** – °C, mb, km/h, mm  
  - **Hybrid (UK)** – °C, mb, mph, mm  (In Development)

* **Location Label** (optional)  
  Custom name shown on the display (e.g. Home, Cabin). Leave blank to use the station neighborhood/city.

---

## 🔑 How to Retrieve Your API Key

If you own a weather station that reports to Weather Underground you can generate an API key for free:

1. Go to [wunderground.com](https://www.wunderground.com) and sign in.
2. Open the **My Devices** (or Member Settings) section.
3. Find the **API Keys** area.
4. Click **Generate** to create a new key.
5. Copy the key and paste it into the Glance app settings.

---

## Pages

- **Main** – Current conditions, temperature, feels-like, pressure, humidity, dewpoint  
- **Wind** – Speed, gust, and direction  
- **Rain** – Today’s total, current rate, status + sparklines  

---

## Notes

- Data refreshes according to the interval set in the Glance layout.
- Free PWS API keys are limited to roughly **1,500 calls per day** and **30 calls per minute**.
- Some icons and advanced conditions require the station to report the necessary sensors (UV, solar radiation, etc.).
