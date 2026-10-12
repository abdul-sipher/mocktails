# Stage 1: Settings + Prayer Engine — Implementation Plan

> Executed inline (executing-plans). Spec:
> `docs/superpowers/specs/2026-10-12-sakinah-full-app-design.md`, Stage 1.

**Goal:** Real, configurable prayer times (Adhan), a settings screen
that recalculates them, a full timetable, prayer windows, and a
first-launch method prompt.

**Architecture:** `PrayerSettings` (model) ← `SettingsStore` (App Group
UserDefaults) → `PrayerEngine` (pure, wraps Adhan) → `DayTimetable`
(value with windows, makruh periods, next prayer) → `AppSession`
publishes `timetable`, `nextPrayer`, `currentWindow` → views.

**Tech:** Swift 5 mode, SwiftUI watchOS 10, Adhan 1.5.0 (SPM via
XcodeGen), XCTest.

## Global constraints
- watchOS 10.0 deployment; XcodeGen `project.yml` is the source of truth.
- App Group: `group.com.abdulelmir.sakinah`; settings key `prayerSettings.v1`.
- Calm reminders default off; no Health prompt unless switched on.
- Never guess times: no location → "Awaiting location…" (UI test relies on this text).
- Keep "N buzzes after rakah N".
- Simulator: `A00AF96C-FB23-4A8A-9210-5233D9961DF3`.

## Tasks

### Task 1: Add Adhan + test target, prove it builds
- `project.yml`: `packages: Adhan: {url: https://github.com/batoulapps/adhan-swift, exactVersion: 1.5.0}`;
  app target depends on package `Adhan`; App Group entitlement;
  new `SakinahWatchTests` (bundle.unit-test, watchOS) compiling the
  pure files (`Models/PrayerSettings.swift`, `Models/DayTimetable.swift`,
  `Models/SalahSession.swift`, `Models/Posture.swift`,
  `Services/PrayerEngine.swift`, `Services/SettingsStore.swift`) plus
  `SakinahWatchTests/`, with `Fixtures/*.json` as resources; scheme
  tests both targets.
- Verify: `xcodegen && xcodebuild build` succeeds with `import Adhan`.
  If the package fails to resolve or build: stop and report.

### Task 2: PrayerSettings + SettingsStore (TDD)
- Produces: `PrayerSettings` (method: `CalculationMethod`, madhhab:
  `Madhhab`, asr: `AsrSchool`, offsets `[String: Int]` via
  `offset(for:)`/`setOffset(_:for:)`, highLatitude:
  `HighLatitudeChoice`, wrist: `Wrist`, rakahHaptics, calmReminders,
  hasChosenMethod), per-field tolerant decoding,
  `PrayerSettings.suggestedMethod(regionCode:)`,
  `CalculationMethod.title`, `CalculationMethod.selectable`.
  `SettingsStore(defaults:)` with `@Published settings`.
- Tests: round-trip through a throwaway suite; decoding `{}` and a
  blob with an unknown extra key gives defaults (no reset); region
  suggestions (AU→MWL, SA→Umm al-Qura, PK→Karachi, nil→MWL).

### Task 3: PrayerEngine + DayTimetable (TDD)
- Produces: `PrayerEngine.parameters(for:)`,
  `PrayerEngine.timetable(on:at:timeZone:settings:) -> DayTimetable?`,
  `PrayerEngine.currentWindow(at:at:timeZone:settings:) -> PrayerWindow?`;
  `DayTimetable` (fajr…isha, sunrise, nextFajr, middleOfNight,
  lastThirdOfNight, isFriday, `prayers`, `next(after:)`,
  `windows`, `window(at:)`, `makruhPeriods`); `PrayerWindow`,
  `MakruhPeriod`.
- Tests: Adhan fixtures (Makkah, London Hanafi, Tehran +3:30, Dubai,
  Singapore) within file variance; Adelaide Dhuhr 12 Oct 2026 between
  12:55 and 13:10 local; Sydney Dhuhr hour 11 on 3 Oct 2026 and 12 on
  4 Oct 2026 (DST); Oslo 21 Jun 2026 non-nil, fajr < sunrise,
  maghrib < isha; `next(after:)` after Isha → tomorrow's Fajr;
  no window between sunrise and Dhuhr; Isha window ends next Fajr with
  preferredEnd = middle of night; +5 Asr offset moves only Asr;
  Friday flag.

### Task 4: AppSession wiring, Health behind the switch, single sheet
- Remove `Services/PrayerTimesService.swift`.
- `AppSession`: `settings: SettingsStore`, `timetable`,
  `currentWindow`, `locationDenied`, `activeSheet: HomeSheet?`
  (`.methodPrompt`, `.dhikr`), `recomputePrayerTimes()` on location,
  30 s tick, settings change; calm reminders start/stop an
  `anxietyTask` (Health auth requested only then).
- `AnxietyDetector.stream`: cancel inner task on termination.
- `LocationService`: report authorization changes.
- `DhikrReminderView` dismisses via `activeSheet = nil`.

### Task 5: Views — Home, Settings, Offsets, Timetable, Method prompt
- Home: five-times strip (Jumuʿah on Fridays, next highlighted),
  window line, location-denied / unavailable messages, Timetable and
  Settings tiles, `.sheet(item: $session.activeSheet)`.
- `SettingsView` (method, Asr, madhhab, high-latitude when |lat| > 48°,
  minute offsets, calm reminders with honest caption). Wrist and rakah
  haptics stay in the model; their controls ship in Stage 3 where they
  take effect.
- `TimetableView` with accessibility ids `time-<prayer>`.
- `MethodPromptView`, not dismissible without Continue.

### Task 6: UI test + verify + ship
- Smoke test: handle method prompt (Continue), open Timetable (Sunrise
  shown), open Settings → change method to Egyptian → Fajr in
  Timetable changes; existing screens still open.
- Full test run green; screenshots to `~/Desktop/Sakinah-watch-screenshots/stage1/`;
  reinstall on simulator; commit and push.
