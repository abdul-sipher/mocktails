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
| Rakah haptic | A double-tap `.success` haptic on each completed rakʿah; distinct notification taps for sajdah 1 vs 2. |
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

This tree is the source for a watchOS app, but the `.xcodeproj` itself
is not included (generated project files are Xcode-version-specific
and fragile to hand-write). The setup is a one-time 2-minute step:

1. Open Xcode → **File ▸ New ▸ Project** → **watchOS ▸ App**.
2. Product name: `SakinahWatch`. Interface: **SwiftUI**. Language: **Swift**.
3. Uncheck "Include Tests" unless you want them. Save the project.
4. Delete the auto-generated `ContentView.swift` and `SakinahWatchApp.swift` from the new project.
5. In Finder, drag the contents of `SakinahWatch/` (Models, Services, Views, `SakinahWatchApp.swift`, `Resources/Ayat.json`) into the Watch App target in the Xcode sidebar. Check **Copy items if needed** and **Add to target: SakinahWatch Watch App**.
6. Open the target's **Info** tab and add the keys from this repo's `Info.plist`:
   - `NSMotionUsageDescription`
   - `NSHealthShareUsageDescription`
   - `NSHealthUpdateUsageDescription`
   - `NSLocationWhenInUseUsageDescription`
7. **Signing & Capabilities** → `+ Capability`:
   - **HealthKit** (check "Background Delivery" if you want anxiety detection when the app is backgrounded)
   - **Background Modes** → enable **Location updates** and **Workout processing**
8. Select an Apple Watch Series 6 or later simulator (altimeter + motion are simulated) or your paired device.
9. ⌘R to run.

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
