import SwiftUI
import CoreLocation
import Combine

@main
struct SakinahWatchApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(session)
                .task { await session.bootstrap() }
        }
    }
}

/// The one sheet Home can show at a time.
enum HomeSheet: String, Identifiable {
    case methodPrompt, dhikr
    var id: String { rawValue }
}

@MainActor
final class AppSession: ObservableObject {
    let motion = MotionService()
    let heart = HeartRateService()
    let anxiety = AnxietyDetector()
    let location = LocationService()
    let mosques = MosqueFinder()
    let quran = QuranService()
    let haptic = HapticService()
    let settings = SettingsStore()

    @Published var nearestMosque: Mosque?
    @Published var timetable: DayTimetable?
    @Published var nextPrayer: PrayerTime?
    @Published var currentWindow: PrayerWindow?
    /// Location known but Adhan could not compute today (extreme latitude).
    @Published var timesUnavailable = false
    @Published var locationDenied = false
    @Published var currentAyah: Ayah?
    @Published var activeSheet: HomeSheet?
    /// True while the next prayer is ≤ 10 min away and a mosque is known.
    @Published var mosqueNudgeActive = false

    /// Latest fix. Screens read this rather than calling location.stream(),
    /// which only supports one listener.
    @Published private(set) var lastCoordinate: CLLocationCoordinate2D?
    /// Prayer window already nudged, so the haptic plays once per prayer.
    private var nudgedPrayerDate: Date?
    /// Runs only while calm reminders are switched on.
    private var calmTask: Task<Void, Never>?
    private var settingsObserver: AnyCancellable?

    func bootstrap() async {
        location.onAuthorizationChange = { [weak self] denied in
            Task { @MainActor in self?.locationDenied = denied }
        }
        location.requestAuthorization()
        if !settings.settings.hasChosenMethod { activeSheet = .methodPrompt }

        // Observe after the change lands (@Published emits on willSet).
        settingsObserver = settings.$settings
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.settingsChanged() }
        applyCalmReminderSetting()

        Task { await refreshLocationContext() }
        Task { await refreshAyahTimer() }
        Task { await refreshPrayerWindow() }
    }

    private func settingsChanged() {
        recomputePrayerTimes()
        applyCalmReminderSetting()
    }

    // MARK: - Calm reminders (opt-in; Health is only asked for here)

    private func applyCalmReminderSetting() {
        if settings.settings.calmReminders {
            guard calmTask == nil else { return }
            calmTask = Task { [weak self] in
                guard let self else { return }
                await self.heart.requestAuthorization()
                await self.observeAnxiety()
            }
        } else {
            calmTask?.cancel()
            calmTask = nil
        }
    }

    private func observeAnxiety() async {
        for await signal in anxiety.stream(using: heart) {
            guard signal == .elevated, activeSheet == nil else { continue }
            activeSheet = .dhikr
            haptic.play(.dhikrReminder)
        }
    }

    // MARK: - Prayer times

    private func refreshLocationContext() async {
        for await coord in location.stream() {
            lastCoordinate = coord
            recomputePrayerTimes()
            nearestMosque = try? await mosques.nearest(to: coord)
            checkMosqueNudge()
        }
    }

    /// Location updates only arrive on movement, so recheck the clock
    /// regularly: rolls to the next prayer, the next day, and opens the
    /// nudge window.
    private func refreshPrayerWindow() async {
        while !Task.isCancelled {
            recomputePrayerTimes()
            try? await Task.sleep(for: .seconds(30))
        }
    }

    func recomputePrayerTimes() {
        guard let coord = lastCoordinate else { return }
        let now = Date()
        let tz = TimeZone.current
        let s = settings.settings
        timetable = PrayerEngine.timetable(on: now, at: coord, timeZone: tz, settings: s)
        timesUnavailable = timetable == nil
        nextPrayer = timetable?.next(after: now)
        currentWindow = PrayerEngine.currentWindow(at: now, at: coord, timeZone: tz, settings: s)
        checkMosqueNudge()
    }

    private func checkMosqueNudge() {
        guard let next = nextPrayer, nearestMosque != nil else {
            mosqueNudgeActive = false
            return
        }
        let remaining = next.date.timeIntervalSinceNow
        mosqueNudgeActive = remaining > 0 && remaining <= 10 * 60
        if mosqueNudgeActive && nudgedPrayerDate != next.date {
            nudgedPrayerDate = next.date
            haptic.play(.mosqueSuggestion)
        }
    }

    private func refreshAyahTimer() async {
        while !Task.isCancelled {
            currentAyah = quran.ayahForCurrentHour()
            try? await Task.sleep(for: .seconds(60 * 30))
        }
    }
}
