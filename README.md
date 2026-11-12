# Little Layers

An iOS 17+ SwiftUI starter app that turns today's local forecast into an outfit checklist for each child.

## Open and run

1. Open `LittleLayers.xcodeproj` in Xcode 16 or later.
2. Complete Xcode's license and first-launch setup if prompted.
3. Select the LittleLayers scheme and an iPhone simulator, then Run. Set a simulated location through the simulator's Features → Location menu.
4. For a physical iPhone, choose your signing team under Signing & Capabilities and a unique bundle identifier.
5. Choose today's start and end hours and tap Get today's outfit. Allow location access when prompted.

## Included

- Daily hour selection, with a default 8 am–4 pm starting window; hours are not saved across app launches.
- Settings groups the outdoor time window, notification preferences, and child profiles.
- Multiple child profiles with editable names, age, and an optional runs-cold preference saved on device.
- Optional daily outfit notifications, scheduled for 6:00 am by default; the time is configurable.
- Fahrenheit/Celsius display.
- Recommendations for clothing, shoes, and extras, with plain-language explanations.
- Rain, new snowfall, forecast ground snow, and a manual ground-snow toggle.
- Loading, location-denied, network-error, and missing-weather states.
- Refresh button and automatic refresh when returning after 15 minutes.
- Black, white, and cream visual theme, with a brief falling-snow animation when ground snow is enabled.

## Recommendation rules

Use the minimum hourly feels-like temperature over the selected inclusive hour range. For children age 4 or younger, subtract 2°C for clothing selection; subtract another 3°C for a child who runs cold. Gender is collected as a profile detail and does not alter temperature advice. Defaults are editable in `Outfit.swift`:

| Feels like | Clothing |
|---|---|
| Below 0°C | Warm base layer, fleece, winter jacket |
| 0–6°C | Long sleeves, thick jacket |
| 7–12°C | Long sleeves, light jacket |
| 13–18°C | T-shirt, hoodie |
| 19°C and above | Light, breathable clothes |

Precipitation probability of at least 40% adds waterproof gear. Any forecast snowfall, forecast snow depth of at least 1 cm, or the manual toggle selects insulated waterproof boots. A range of at least 6°C adds a removable-layer reminder. These are customizable everyday heuristics, not validated pediatric guidance or extreme-weather alerts; the app does not tailor advice for infants.

## Weather and privacy

The app uses Open-Meteo's forecast endpoint with feels-like temperature, precipitation probability, snowfall, and snow depth. It fetches seven days of hourly data. Hours use the forecast location's timezone. A network connection and location permission are required; city search and offline forecasts are not included. Outfit notifications are off until enabled and permission is granted. The app schedules alerts from the latest fetched forecast and refreshes the upcoming schedule when it is opened; if left closed, later alerts use that saved forecast snapshot.

Approximate location is requested with kilometer-level desired accuracy (the operating system may still return more precise coordinates). Coordinates are transmitted to Open-Meteo via HTTPS. Child names, ages, and comfort preferences are stored in local UserDefaults and are not included in weather requests. No backend or analytics is included.

API documentation: https://open-meteo.com/en/docs
Review Open-Meteo's current licensing and commercial usage terms before distributing commercially: https://open-meteo.com/en/terms

## Verification status

The Xcode project passed `plutil -lint` and built successfully for the iOS Simulator using Xcode 26.3 after the notification and profile changes. Simulator services reported a stale service version during the build, so the app was compiled but not launched in a simulator. No app icon or distribution signing is configured.
