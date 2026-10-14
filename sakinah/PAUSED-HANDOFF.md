# Sakīnah — paused handoff (15 Oct 2026)

**Status: PAUSED by Abdul on 15 Oct 2026** to free up headspace. Nothing is
half-done: every stage below is built, tested in the simulator, committed and
pushed. A reminder on Abdul's Mac fires **29 Oct 2026, 9:00am** and can be
pushed back a week at a time (see "The reminder" at the bottom).

To resume: open Claude Code in `~/mocktails` and say *"resume Sakīnah"*.
Claude should read this file first, then `README.md`, then the spec.

---

## 1. Where everything is

| What | Where |
|---|---|
| Code | `~/mocktails/sakinah` — GitHub `abdul-sipher/mocktails`, branch `claude/islamic-prayer-watch-app-41EsL`, last commit `56ddd27` (all pushed; no pull request opened) |
| Project definition | `project.yml` (XcodeGen). Run `xcodegen` in `sakinah/` to make `SakinahWatch.xcodeproj` (not committed) |
| Design / decisions | `docs/superpowers/specs/2026-10-12-sakinah-full-app-design.md` (incl. stress-test results and judgement calls) |
| Stage 1 plan | `docs/superpowers/plans/2026-10-12-stage1-settings-prayer-engine.md` |
| User-facing docs | `README.md` (features, permissions, unsupported, release checklist) |
| Screenshots | `~/Desktop/Sakinah-watch-screenshots/` (`stage1/`, `full-app/`, plus the first set) |
| Old spec Abdul pasted | Folded into the design spec above (section "Programme") |
| Earlier scaffold (not used) | `~/Documents/New project/SalahCompanionWatch` — ~600 lines of simulated data, ideas only |
| Reusable elsewhere | Kids Islam App has qibla/compass code at `~/Desktop/Bizo/Kids Islam App/app` |
| Claude memory | `~/.claude/projects/-Users-Abdulelmir-1-mocktails/memory/sakinah-watch-app.md` |

## 2. Decisions already made (don't re-ask)

| Decision | Choice | Who |
|---|---|---|
| Audience | Public App Store, **free** | Abdul |
| Publisher | Abdul's own name (same as Kids Islam app) | Abdul (from Kids app) |
| Calculation method | Asked on first launch, suggested by device region | Abdul |
| Asr | Asked on first launch, separate from madhhab | Abdul |
| Du'a/adhkar source | Hisn al-Muslim selection, own English meanings, scholar check before release | Abdul |
| iPhone companion | After the watch app | Abdul |
| Family/child reminders | Out of this version | Abdul |
| Prayer maths | Adhan 1.5.0 (batoulapps, MIT) instead of home-made | Claude, agreed |
| Salah tracking | Tap-to-count is primary; motion is "experimental" until validated | Spec |
| Calm reminders | Off by default (opt-in) | Spec |
| Rakah haptic | **N buzzes after rakah N — never change** (originally requested) | Abdul |
| Method prompt | Cannot be skipped; one tap with suggestion preselected | Claude default |
| Isha end / makruh minutes | Isha "best before midnight"; makruh = sunrise+15, Dhuhr−5, Maghrib−15 (labelled approximate) | Claude default, scholar to confirm |

## 3. What is built (stages 1–7 of the spec)

1. **Settings + prayer engine** — Adhan methods (MWL, ISNA, Umm al-Qura, Egyptian, Karachi, Dubai, Moonsighting, Kuwait, Qatar, Singapore, Tehran, Turkey); madhhab; Asr; ±30 min per-prayer offsets; high-latitude rule (shown when |lat| > 48°); prayer windows (none sunrise→Dhuhr; Isha to next Fajr, best before midnight); Timetable (sunrise, makruh, last third); first-launch prompt (method, madhhab, Asr, wrist); settings saved in App Group `group.com.abdulelmir.sakinah`, tolerant decoding.
2. **Watch face + alerts** — `SakinahWidgets` extension (next prayer: circular/corner/inline/rectangular + Smart Stack relevance; nearest mosque). Prayer-time notifications + heads-up (0/5/10/15/20 min) naming nearest mosque and "make wudu before you leave"; 3 days ahead (≤60 pending); background refresh every ~6 h; triggers carry time zone; alerts shown while app is open.
3. **Salah + wudu** — tap-to-count tracker (tap after each sajdah; pause/undo/finish; ± correction; review screen; adhkar after salah; history save); seated → manual only; travel → 2 rakʿāt for Dhuhr/Asr/Isha; khushu mode (dark, one dim number, long-press to finish); gentle vs strong buzz (still N). Experimental motion mode: confidence, holds when unsure, wrist setting, calibration (4 averaged postures only), HKWorkoutSession keeps sensors awake. Tashahhud decided from rakah state. Wudu: 9 steps (niyyah, hands, mouth, nose, face, right arm, left arm, head+ears, feet), experimental motion counting, manual "I have wudu" status, ghusl checklist (Bukhari 248/249, Muslim 316/317).
4. **Qibla + mosques** — compass (true/magnetic labelled, accuracy warnings, upright letters, no-compass fallback), shortest turn, aligned buzz, distance to Makkah. Mosque search (mosque/masjid/musalla/Islamic centre, merged), walking + driving ETAs (MKDirections), directions in Maps, favourites, home/work, cached results with date, "Can I make it?". Iqamah/Jumuʿah = "Not available".
5. **Du'as, adhkar, Qur'an** — `Resources/Duas.json`: 27 du'as in 10 categories + 14 adhkar (after-salah, morning/evening); favourites; Crown tasbih (33/99/100, phrase switch); memorisation (Al-Fatihah + Juz ʿAmma, 564 ayat checked; streak; revision queue); time-of-day verse labelled a suggestion with excerpt flags; Hijri date (Umm al-Qura, ±2 day offset); Ramadan suhoor/iftar card.
6. **Wellbeing + records** — calm reminders skip salah/khushu/walking-running, 15-min cooldown, rotating sourced texts (3:134, 13:28, Bukhari 6114, 3:173), helpful/not-helpful feedback raises threshold (20→41 bpm); history ticks, qada count + daily 8pm reminder (opt-in), full-day streak, gratitude journal, privacy mode, mindful minutes (opt-in), delete all data (with confirm).
7. **Polish** — placeholder icon, accent colour, privacy manifest, Arabic strings (56, draft), reduced motion, VoiceOver labels, README.

## 4. How it was verified (evidence)

- **57 logic tests pass** (`SakinahWatchTests`): Adhan reference timetables for Makkah, London (Hanafi), Tehran (+3:30), Dubai, Singapore (whole year); Sydney DST; Adelaide half-hour zone; Oslo midsummer; windows; alert planner; salah tracker; calibration; qibla bearing (Sydney ≈ 278°); mosque merging; du'a content completeness; memorisation; Ramadan 1448; records.
- **UI walkthrough passes** (`SakinahWatchUITests/ScreenSmokeTests`, ~6 min): method prompt, Home, Qur'an, Du'as (source shown), Adhkar + tasbih counting, Wudu (Next), Salah (2 taps = 1 rakah, undo, finish, review), Mosques (+ detail with walking time), Qibla, Timetable, Settings (method change moves Fajr), History (missed → qada 1).
- **Seen live in simulator:** Stockholm mosque nudge (Masjid Sheikh Said 831 m), London Dhuhr alert on the minute + nudge (Exhibition Islam 810 m), Moscow Asr alert with Home rolling to Maghrib instantly, Johannesburg nudge (President Street Jamaat Khana 220 m), Lakemba mosques (Lakemba Musallah 151 m etc.).
- Bugs found and fixed: prayer times a day early (equation of time), Asr formula, half-hour zones truncated, Mosques screen hijacking the location stream, alerts without time zone, Home showing a started prayer as "next", nudge minutes stale, app launching in Arabic (catalog lacked English), Arabic left-aligned under RTL.

## 5. Not verified / known gaps (be honest when resuming)

- **Needs Abdul's real watch:** posture/rakah detection, calibration, wudu motion counting, heart rate + HRV (calm reminders), compass heading/accuracy, haptic feel (N buzzes, gentle taps, qibla buzz), workout session keeping app awake, background refresh, complications on an actual watch face (widget built and embedded but never placed on a face), mindful-minutes save, Health permission flows.
- Heart rate on watchOS is only sampled periodically outside workouts — calm reminders may rarely fire. Documented in README.
- Arabic UI is partial (56 strings); most screens stay English in Arabic mode. Draft, needs native review.
- `MotionService.stream()` still supports one listener (left as the original brief asked).
- Automatic salah records the session using the detector's current rakah; unvalidated.
- Recitation audio, iqamah data source, iPhone companion, family reminders: not built (by decision).
- Stage 8 (Core ML posture classifier) needs labelled recordings from real prayers on Abdul's watch.

## 6. Before App Store release (blocking)

1. **Scholar review:** `SakinahWatch/Resources/Duas.json` (every du'a and dhikr), ghusl checklist (`Views/WuduView.swift`), travel guidance (`Views/RecordsViews.swift` — distances/rulings per madhhab), makruh minutes and Isha "best before midnight" (`Models/DayTimetable.swift`), default Asr per madhhab. Could go through the same muftis as the Kids Islam app.
2. **Native Arabic review:** `SakinahWatch/Localizable.xcstrings` (all marked needs_review).
3. **Translation licence:** English in `Resources/Ayat.json` matches Sahih International — get permission or replace (own wording, or a public-domain translation).
4. **Real app icon** (current one is a Claude placeholder: gold crescent + star on dark green).
5. **Apple Developer enrolment** (also pending for the Kids Islam app), then signing team, App Group and HealthKit capability on the account.
6. **Privacy policy URL** (required for HealthKit apps); App Store privacy answers = no data collected.
7. Test on a real watch (section 5) and fix what it shows.

## 7. Suggested order when resuming

1. Install on Abdul's watch (Xcode → his watch as destination, set team) and walk every screen.
2. Fix whatever the real watch shows (sensors, haptics, complications).
3. Send du'as/guidance for scholar review; Arabic for native review (in parallel).
4. Icon, Ayat translation decision, privacy policy.
5. TestFlight, then App Store.
6. Later: Stage 8 motion classifier, iPhone companion, iqamah source.

## 8. Running it (cheat sheet)

```sh
cd ~/mocktails/sakinah && xcodegen && open SakinahWatch.xcodeproj
# Simulators live in DeviceHub in Xcode 27 (Xcode ▸ Open Developer Tool ▸ DeviceHub)
# Watch simulator used: Apple Watch Series 11 (46mm) A00AF96C-FB23-4A8A-9210-5233D9961DF3
xcrun simctl location A00AF96C-FB23-4A8A-9210-5233D9961DF3 set -33.9205,151.0756   # Lakemba
TEST_RUNNER_SHOT_DIR=/tmp/shots xcodebuild test -project SakinahWatch.xcodeproj \
  -scheme SakinahWatch -destination 'platform=watchOS Simulator,id=A00AF96C-FB23-4A8A-9210-5233D9961DF3'
```

Tricks: to see alerts/nudges, launch with `SIMCTL_CHILD_TZ=<city zone>` and that
city's location when its next prayer is a few minutes away. `simctl io screenshot`
can stall; capture in a loop that starts before the event. Closing DeviceHub
shuts the simulator down mid-test. Never add an `info:` block to the app target
in project.yml (XcodeGen overwrites Info.plist).

## 9. The reminder

A small job on Abdul's Mac (`~/Library/LaunchAgents/com.abdulelmir.sakinah-reminder.plist`,
script `~/.claude/reminders/sakinah-reminder.sh`, date in
`~/.claude/reminders/sakinah-reminder.date`) checks daily at 9:00am and at login. From
29 Oct 2026 it pops up a box: **Push back 1 week**, **Push back 2 weeks**, or
**Resume Sakīnah** (opens this file and switches the reminder off). To cancel it
entirely: `launchctl unload ~/Library/LaunchAgents/com.abdulelmir.sakinah-reminder.plist`.
