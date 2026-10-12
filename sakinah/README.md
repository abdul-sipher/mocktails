# Sakīnah — Islamic Apple Watch Companion

A watch-only watchOS app (watchOS 10+) for prayer times, salah and wudu
tracking, qibla, nearby mosques, du'as and adhkar. Free. All personal
data stays on the watch.

> *"Truly, in the remembrance of Allah do hearts find rest."* — Qur'an 13:28

Design and decisions: `docs/superpowers/specs/2026-10-12-sakinah-full-app-design.md`.

## Building

The Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen); the `.xcodeproj` is not committed.

```sh
brew install xcodegen
cd sakinah
xcodegen
open SakinahWatch.xcodeproj        # pick an Apple Watch simulator, press Run
```

Command line:

```sh
xcodebuild -project SakinahWatch.xcodeproj -scheme SakinahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

Targets: `SakinahWatch` (app), `SakinahWidgets` (complications and Smart
Stack), `SakinahWatchTests` (logic tests), `SakinahWatchUITests`
(screen walkthrough). In Xcode 27 simulators open in **DeviceHub**
(Xcode ▸ Open Developer Tool), which replaces the Simulator app.

### Tests

```sh
xcrun simctl location <udid> set -33.9205,151.0756        # Lakemba
TEST_RUNNER_SHOT_DIR=/tmp/shots xcodebuild test -project SakinahWatch.xcodeproj \
  -scheme SakinahWatch -destination 'platform=watchOS Simulator,id=<udid>'
```

Logic tests cover prayer times against the Adhan library's published
reference timetables (Makkah, London, Tehran, Dubai, Singapore), Sydney
daylight saving, Adelaide's half-hour zone, Oslo midsummer, prayer
windows, alert planning, the salah tracker, calibration maths, qibla,
mosque merging, du'a content completeness, memorisation, Hijri/Ramadan
dates and records. The UI test opens every screen.

## What is implemented

| Area | What works |
|---|---|
| Prayer times | Adhan 1.5 (MIT). Methods: MWL, ISNA, Umm al-Qura, Egyptian, Karachi, Dubai, Moonsighting Committee, Kuwait, Qatar, Singapore, Tehran, Turkey. Asr standard/Hanafi set separately from madhhab. Per-prayer minute offsets. High-latitude rule. Recalculates on change. |
| Home | Next prayer + countdown, current prayer window (no window sunrise→Dhuhr; Isha "best before" midnight), today's five times, Jumuʿah on Fridays, Hijri date, Ramadan suhoor/iftar card, nearest mosque, mosque nudge in the 10 minutes before a prayer, wudu status. |
| Timetable | Five prayers, sunrise, makruh periods (approximate), last third of the night. |
| Alerts | Prayer-time notifications and an optional heads-up (5–20 min) naming the nearest mosque and reminding to make wudu; 3 days scheduled ahead, refreshed in the background. Qada reminder (opt-in). |
| Watch face | WidgetKit complications (circular, corner, inline, rectangular) and Smart Stack: next prayer with countdown; nearest mosque. |
| Salah | Tap-to-count tracker (one tap per sajdah; N buzzes after rakah N), pause, finish, undo, ± correction, post-prayer review, adhkar after salah, any length, seated prayer, travel (qasr) defaults, khushu mode. Motion counting is **experimental**: confidence shown, holds when unsure, either wrist, personal calibration, workout session keeps sensors awake. |
| Wudu | Guided steps (right/left arm separate), experimental motion counting with manual Next, "I have wudu" status set only by the user, ghusl checklist with sources. |
| Qibla | Large compass, bearing from true north, heading (true or magnetic, labelled), shortest turn, aligned state + optional haptic, distance to Makkah, accuracy warnings, no-compass fallback. |
| Mosques | Apple Maps search (mosque, masjid, musalla, Islamic centre), walking and driving ETAs, directions in Maps, favourites, home/work, saved results with date, "Can I make it?". |
| Du'as | 27 du'as in 10 categories: Arabic, transliteration, meaning, source, excerpt flag, favourites. |
| Adhkar | After-salah and morning/evening sets with tap counters; tasbih on the Digital Crown. |
| Qur'an | Time-of-day verse (labelled a suggestion), memorisation goals for Al-Fatihah and Juz ʿAmma with streak and revision. |
| Wellbeing | Calm reminders, off by default: heart rate above baseline with low HRV, not while walking/running, not during salah or khushu mode, 15-minute cooldown, rotating sourced texts, "helpful / not helpful" feedback that makes reminders less eager. |
| Records | Prayer history, qada count, full-day streak, gratitude journal, privacy mode, mindful minutes in Health (opt-in), delete all data. |
| Accessibility | VoiceOver labels on custom controls, reduced motion respected, Arabic shown right-to-left; Arabic UI strings drafted for the main screens. |

## Permissions

| Permission | When asked | Why |
|---|---|---|
| Location (when in use) | First launch | Prayer times, qibla, nearby mosques |
| Notifications | After choosing the calculation method | Prayer alerts |
| Health: heart rate, HRV (read) | Only when calm reminders are switched on | Calm reminders |
| Health: workouts (write) | First automatic-motion salah | Keeps the watch awake during salah; no workout is saved |
| Health: mindful minutes (write) | Only when that setting is switched on | Logs salah time |
| Motion | First motion-counting use | Wudu and salah motion counting, calibration |

## Not supported (and why)

- **Silencing notifications or turning on Focus during salah:** no public API.
- **Iqamah and Jumuʿah congregation times:** Apple Maps does not have them and there is no verified source yet. Shown as "Not available", never guessed.
- **Recitation audio:** none in v1 (licensing).
- **iPhone companion:** planned after the watch app; nothing here requires an iPhone.
- **Continuous background heart-rate monitoring:** watchOS only delivers heart rate when the system samples it; calm reminders work when samples arrive, which is not guaranteed outside workouts.

## Needs a real Apple Watch to verify

Posture and rakah detection, calibration, wudu motion counting, heart
rate and HRV (calm reminders), compass heading and accuracy, haptic
patterns (N buzzes, gentle taps, qibla buzz), workout session keeping the
app awake, background refresh, complications on a real watch face. The
simulator has no motion, heart-rate or compass sensors.

## Before App Store release

- **Scholar review:** `SakinahWatch/Resources/Duas.json` (all du'as and
  adhkar), ghusl checklist, travel guidance, makruh-period minutes, Isha
  "best before midnight", default Asr per madhhab.
- **Native Arabic review:** `SakinahWatch/Localizable.xcstrings` (marked needs review).
- **Translation licence:** the English in `Resources/Ayat.json` matches
  Sahih International; get permission or replace it. Du'a meanings are
  Sakīnah's own wording.
- **App icon:** `Assets.xcassets/AppIcon.appiconset` is a placeholder.
- **Signing:** set your team; App Group `group.com.abdulelmir.sakinah`
  and HealthKit capability must exist on the Apple Developer account.
- **Privacy policy URL** (required for HealthKit apps) and App Store
  privacy answers: no data collected (`PrivacyInfo.xcprivacy`).

## Privacy

On-device only. No accounts, analytics or network calls except Apple
Maps search and routing. Raw sensor data is never stored; calibration
keeps only four averaged wrist positions.
