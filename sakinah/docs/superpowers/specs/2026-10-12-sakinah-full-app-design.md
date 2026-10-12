# Sakīnah — full watch app: programme and Stage 1 design

Date: 12 Oct 2026. Status: draft for Abdul's review.
Inputs: the agreed feature list (11 Oct), Abdul's earlier product spec
("Build an Islamic companion app for Apple Watch…"), and the current
code on `claude/islamic-prayer-watch-app-41EsL`.

## Decisions already made

| Decision | Choice |
|---|---|
| Audience | Public App Store release. Apple review standards from the start. |
| Default calculation method | Asked on first launch; suggested from the user's country. |
| Asr | Asked on first launch, set independently of madhhab. |
| Adhkar/du'a source | Hisn al-Muslim, with references; scholar check before release. |
| iPhone companion | After the watch app is complete. Watch app must stand alone. |
| Family/child reminders | Out of this version. |
| Prayer-time maths | Adhan library (batoulapps/adhan-swift 1.5, MIT, SPM, watchOS 6+). Replaces `PrayerTimesService`'s own maths. |
| Salah tracking | Manual tracking is the primary mode. Automatic posture recognition is labelled "experimental" until validated with real recorded data. |
| Calm reminders | Off by default (opt-in). |

## Principles (apply to every stage)

1. **Never fabricate.** No invented mosque data, iqamah times, travel
   times or sensor readings. Missing data is shown as missing.
   Remaining demo data is labelled "Demo" on screen.
2. **No accuracy claims for sensors.** Posture, wudu and agitation
   detection are aids, shown with confidence, with manual override.
3. **Minimal distraction in worship.** Haptics optional; no prompts
   during an active salah session; khushu mode reduces visuals.
4. **On-device and private.** No accounts, no analytics. History is
   deletable; privacy mode keeps no worship sessions. Raw sensor data
   is only stored with explicit consent (calibration/research).
5. **Permissions when relevant.** Location at first prayer-time need,
   Health only when calm reminders are switched on, Motion only when
   automatic tracking is used.
6. **Content is sourced.** Every ayah, hadith, du'a and dhikr carries
   its reference; excerpts are marked as excerpts. Suggested verses for
   a time of day are presented as suggestions, not prescribed practice.

## Programme

Each stage gets its own plan, is built, tested in the simulator, and
committed before the next starts. Abdul tests on a real watch where
marked ⌚.

| # | Stage | Contents |
|---|---|---|
| 1 | Settings + prayer engine | Adhan engine; settings (method, madhhab, Asr, offsets, high-latitude, wrist, haptics, calm-reminder switch); prayer windows; full timetable; Home shows all five times + current window; first-launch method/Asr prompt. Detailed below. |
| 2 | Watch face + alerts | WidgetKit extension: complications (next prayer + countdown, nearest mosque) and Smart Stack. UserNotifications: prayer alerts, optional heads-up N min before, mosque nudge when the app is closed. Settings shared via App Group. |
| 3 | Salah + wudu | Manual tracker (start, pause, finish, reset; rakah ±; sajdah 1/2; prayer length from prayer or custom; optional rakah haptics — keep N buzzes after rakah N; post-prayer review/correct). HKWorkoutSession during salah ⌚. Experimental auto mode with confidence display and quiet fallback; wrist setting; seated prayer. Calibration recording (consent). Wudu: steps hands, mouth, nose, face, right arm, left arm, head and ears, feet (niyyah as an optional first step); step progress, reset, completion; manual "I have wudu" status (never inferred); reminder before leaving for a mosque; ghusl checklist. Onboarding flow (method, Asr, wrist, permissions explained). |
| 4 | Qibla + mosques | Qibla section: large compass, cardinal points, qibla bearing (true north, from Adhan), device heading (true when available, else magnetic, labelled), shortest turn left/right with angle, aligned state + optional haptic, distance to Makkah, sensor/permission states. Mosques: search mosques, musallas, Islamic centres (MKLocalSearch); walking + driving ETA (MKDirections, available on watchOS); open directions in Maps; favourites; home/work prayer places; cached results with "last updated"; "Can I make it?" (travel time vs prayer start; vs iqamah only when verified). Iqamah/Jumu'ah fields exist but show "not available" — no verified source in v1. |
| 5 | Du'a, Qur'an, adhkar | Du'a library (10 categories: anxiety, anger, forgiveness, knowledge, parents, travel, sleep, gratitude, illness, daily needs) with Arabic, transliteration, meaning, reference, excerpt flag, favourites, reading screen. Morning/evening adhkar; post-salah adhkar offered after the final tashahhud/finish. Tasbih on the Digital Crown (haptic at 33/99). Small memorisation/revision goals. Time-aware Qur'an reminders (replaces "ayah of the hour" wording). Ramadan mode: suhoor/iftar countdown; Hijri date (Umm al-Qura calendar). Audio only if licensed — none in v1. |
| 6 | Wellbeing + records | Calm reminders, opt-in: HR above baseline + low HRV + low movement (not during workout/salah), cooldown, gentle haptic, verified content (3:134, 13:28, hadith on anger with source), dismiss + "was this helpful?" feedback; switching off stops monitoring. Prayer history, optional qada log + reminders, mindful minutes to Health, gratitude journal, privacy mode, khushu mode, customisable haptics, travel settings (with reviewed guidance), delete all history. |
| 7 | Polish + docs | App icon, Arabic localisation with RTL, VoiceOver labels, Dynamic Type, reduced motion, colour palette (dark, restrained green/gold/cyan), App Store privacy text. Docs: features, permissions, unsupported capabilities, remaining placeholders, what needs an iPhone. |
| 8 | Research (later) | Labelled motion recordings from real prayers ⌚ → evaluate a Core ML posture classifier; only promoted out of "experimental" if validation passes. |

Out of scope for this version: iPhone companion, family/child
reminders, recitation audio, iqamah data source, silencing
notifications / Focus control (no public API).

## Stage 1 design: settings and prayer engine

### Units

- **`PrayerSettings`** (model, `Codable`): `method` (Adhan
  `CalculationMethod`), `madhhab` (hanafi/shafii/maliki/hanbali),
  `asr` (standard/hanafi — independent of madhhab, defaulted from it
  at first choice only), `offsets` (minutes per prayer, −30…+30),
  `highLatitudeRule` (auto/middleOfTheNight/seventhOfTheNight/
  twilightAngle), `wrist` (left/right), `rakahHaptics` (Bool, default
  true), `calmReminders` (Bool, default false), `hasChosenMethod`.
- **`SettingsStore`** (`ObservableObject`): loads/saves
  `PrayerSettings` as JSON in `UserDefaults` (App Group suite once
  Stage 2 adds the widget; standard suite until then — one constant).
- **`PrayerEngine`**: pure, no CoreLocation dependency. Input:
  coordinate, date, time zone, settings. Output: `DayTimetable`.
  Wraps Adhan (`PrayerTimes`, `SunnahTimes`, `Qibla` later).
- **`DayTimetable`** (value): fajr, sunrise, dhuhr, asr, maghrib,
  isha; `isFriday`; `lastThirdOfNight`; `makruhPeriods` (sunrise →
  sunrise+15 min; dhuhr−5 min → dhuhr; asr-makruh → maghrib, defined as
  maghrib−15 min → maghrib for all madhhabs in v1, labelled
  "approximate"; these minute values go on the scholar-check list);
  functions
  `next(after:)` (rolls into tomorrow's Fajr) and `window(at:)`.
- **Prayer windows**: Fajr → sunrise; Dhuhr → Asr; Asr → Maghrib;
  Maghrib → Isha; Isha → next Fajr, with "preferred until midnight"
  (midpoint of Maghrib and next Fajr) shown; between sunrise and Dhuhr there
  is no current prayer window. Window wording on screen: "Dhuhr time
  until 4:18 pm".
- **`AppSession`** keeps `lastCoordinate`; computes `timetable` and
  `nextPrayer` from `PrayerEngine` on location, on settings change, and
  on the existing 30 s tick. Mosque nudge logic unchanged.
- **Views**: `SettingsView` (new tile + gear on Home), `TimetableView`
  (new tile), `MethodPromptView` (sheet on Home while
  `hasChosenMethod == false`; suggests a method from the device
  region: AU/NZ/UK/EU → MWL, US/CA → ISNA, Saudi → Umm al-Qura,
  Egypt → Egyptian, Pakistan/India/Bangladesh → Karachi, UAE → Dubai,
  Singapore/Malaysia → Singapore, Turkey → Turkey, else MWL), Home
  `NextPrayerCard` + new five-times strip + current window line.
- **Removed**: `PrayerTimesService.swift` (replaced). `PrayerName` and
  `PrayerTime` stay.

### Data flow

Location → `AppSession.lastCoordinate` → `PrayerEngine.timetable(…,
settingsStore.settings)` → published `timetable` / `nextPrayer` →
Home, Timetable, mosque nudge. Settings change → recompute
immediately.

### Error handling

- No location yet: Home shows "Waiting for location" and a button to
  open Settings ▸ Location help; no times are guessed.
- Location denied: explicit message with how to enable.
- Adhan returns nil (extreme latitude day): show "Times unavailable
  today at this latitude — change the high-latitude rule" with a link
  to the setting.

### Testing

- Unit tests (new `SakinahWatchTests` target) for `PrayerEngine`
  against published reference times (±2 min): Sydney (MWL, Shafi'i),
  Adelaide (half-hour zone), London (MWL, Hanafi), Makkah (Umm
  al-Qura), Oslo in June (high-latitude rule applied, no nil).
  References are taken from Adhan's own published test fixtures where
  they cover the case, otherwise from the authority's timetable, cited
  in the test.
- Unit tests: `next(after:)` across midnight; `window(at:)` between
  sunrise and Dhuhr returns none; offsets shift only their prayer;
  settings round-trip through the store.
- UI smoke test extended: Settings opens, changing method changes a
  displayed time; Timetable opens; method prompt appears on first launch
  and is dismissed by choosing.

### Done for Stage 1

Builds with no errors; all unit and UI tests pass in the watch
simulator; screenshots of Home, Settings, Timetable and the method
prompt saved to the Desktop screenshot folder; committed and pushed.
