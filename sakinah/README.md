# Sakīnah — Islamic Apple Watch Companion

A watchOS app that walks with you through wudu and salah using wrist
motion, reminds you of Allah when your heart quickens, surfaces an
ayah for the moment, and points you to the nearest mosque.

> *"Truly, in the remembrance of Allah do hearts find rest."* — Qur'an 13:28

## Features

| Feature | How it works |
|---|---|
| Wudu tracker | Detects washing-gesture repetitions via `CMDeviceMotion` and advances through the 9 canonical steps. |
| Salah tracker | Classifies qiyām / rukūʿ / sujūd / jalsa / tashahhud from wrist gravity + altitude; counts rakʿāt and which sajdah you're in. |
| Rakah haptic | N `.success` haptics on each completed rakʿah — 1 buzz after the 1st rakah, 2 after the 2nd, and so on. Distinct notification taps for sajdah 1 vs 2. |
| Dhikr reminder | `HealthKit` HR above rolling baseline + low HRV → suggests a pause for tasbīḥ. |
| Ayah of the hour | Bundled `Ayat.json` maps verses to hours of the day; refreshes every 30 minutes. |
| Mosque finder | `MKLocalSearch` query for "mosque" ranked by distance; suggests the nearest when a prayer window opens. |
| Prayer times | Self-contained astronomical calculation (ISNA default, configurable). |

## Project layout

```
SakinahWatch/
├── SakinahWatchApp.swift         # @main, app session, bootstrap tasks
├── Info.plist                    # usage descriptions, background modes
├── Models/
│   ├── Posture.swift             # Posture + WuduStep enums
│   ├── SalahSession.swift        # PrayerName, SalahSession, PrayerTime
│   ├── Ayah.swift
│   └── Mosque.swift
├── Services/
│   ├── MotionService.swift       # 50Hz CoreMotion stream + altimeter
│   ├── SalahPostureDetector.swift
│   ├── WuduStepDetector.swift
│   ├── HeartRateService.swift    # HealthKit anchored query
│   ├── AnxietyDetector.swift     # HR-vs-baseline + HRV heuristic
│   ├── LocationService.swift
│   ├── MosqueFinder.swift        # MKLocalSearch
│   ├── PrayerTimesService.swift  # ISNA astronomical solution
│   ├── QuranService.swift
│   └── HapticService.swift       # WKInterfaceDevice cues
├── Views/
│   ├── HomeView.swift
│   ├── WuduView.swift
│   ├── SalahView.swift           # SalahStartView + SalahLiveView
│   ├── AyahView.swift
│   ├── MosqueFinderView.swift
│   └── DhikrReminderView.swift
└── Resources/
    └── Ayat.json                 # hour-tagged verses
```

## Building in Xcode

The Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen); the `.xcodeproj` is
not committed.

```sh
brew install xcodegen
cd sakinah
xcodegen                       # writes SakinahWatch.xcodeproj
open SakinahWatch.xcodeproj    # or build from the command line:
xcodebuild -project SakinahWatch.xcodeproj -scheme SakinahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

`project.yml` sets up a watch-only app (watchOS 10+), bundles
`Resources/Ayat.json`, uses `SakinahWatch/Info.plist` (usage strings,
`WKWatchOnly`, background modes) and the HealthKit entitlement. To run
on a real watch, pick your team under **Signing & Capabilities**.

### Smoke test in the simulator

`SakinahWatchUITests` launches the app, closes the Health prompt, and
opens Home, Ayah, Wudu (taps Next), Salah (± rakah) and Mosques:

```sh
xcrun simctl location <udid> set -33.9205,151.0756   # Lakemba
TEST_RUNNER_SHOT_DIR=/tmp/shots xcodebuild test -project SakinahWatch.xcodeproj \
  -scheme SakinahWatch -destination 'platform=watchOS Simulator,id=<udid>'
```

Motion, the barometer and heart rate are not simulated, so posture
detection, wudu rep counting and the dhikr reminder need a real watch.

## Calibration notes

The posture detector in `SalahPostureDetector.swift` uses first-pass
gravity and altitude thresholds assuming the watch is worn on the
**left wrist** with the digital crown facing the user's hand (Apple's
default "orient right" setting with the watch on the left). If you
wear it differently, flip the sign on `gravityY` comparisons or add
a settings toggle.

A proper deployment would record a short calibration session per user
(stand-bow-prostrate three times) and fit the thresholds to the
samples rather than hard-coding them.

## Privacy

- All motion, HR, and location processing happens on-device.
- No network calls except `MKLocalSearch` (Apple Maps) for mosque lookup.
- `HealthKit` reads are opt-in; the anxiety detector can be turned off.

## Web prototype

`../watch-prototype.html` is a click-through of the watch faces for
design review — open it in a browser, no build needed.
