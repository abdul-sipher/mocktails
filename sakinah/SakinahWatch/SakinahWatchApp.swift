import SwiftUI
import CoreLocation
import Combine
import WidgetKit
import WatchKit
import UserNotifications
import CoreMotion

@main
struct SakinahWatchApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(session)
                .task { await session.bootstrap() }
        }
        // Keeps alerts scheduled a few days ahead even if the app is not opened.
        .backgroundTask(.appRefresh) { _ in
            await AppSession.backgroundRefresh()
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
    let notifications = NotificationScheduler()
    lazy var duaLibrary = DuaLibrary.load()
    let mindful = MindfulService()
    private let activity = CMMotionActivityManager()

    @Published var nearestMosque: Mosque?
    @Published var timetable: DayTimetable?
    @Published var nextPrayer: PrayerTime?
    @Published var currentWindow: PrayerWindow?
    /// Location known but Adhan could not compute today (extreme latitude).
    @Published var timesUnavailable = false
    @Published var locationDenied = false
    @Published var alertsDenied = false
    @Published var currentAyah: Ayah?
    @Published var activeSheet: HomeSheet?
    @Published private(set) var records = Records.load()
    /// True while a salah screen is open: no calm reminders then.
    @Published var salahActive = false
    /// Set by the user only; never inferred from time or motion.
    @Published private(set) var wuduSince: Date? = AppGroup.defaults.object(forKey: "wuduSince") as? Date
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
    private var lastPlan: [PlannedAlert] = []

    func bootstrap() async {
        UNUserNotificationCenter.current().delegate = ForegroundAlertPresenter.shared
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
        haptic.gentle = settings.settings.gentleBuzz
        if settings.settings.hasChosenMethod { await prepareAlerts() }
        AppSession.scheduleNextBackgroundRefresh()

        Task { await refreshLocationContext() }
        Task { await refreshAyahTimer() }
        Task { await refreshPrayerWindow() }
    }

    private func settingsChanged() {
        recomputePrayerTimes()
        applyCalmReminderSetting()
        haptic.gentle = settings.settings.gentleBuzz
        Task { await notifications.scheduleQadaReminder(settings.settings.qadaReminder && records.qadaOwed > 0) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Records (on this watch only)

    func updateRecords(_ change: (inout Records) -> Void) {
        change(&records)
        records.save()
        Task { await notifications.scheduleQadaReminder(settings.settings.qadaReminder && records.qadaOwed > 0) }
    }

    /// Called when a tracked salah is finished and reviewed.
    func salahFinished(prayer: PrayerName?, rakahs: Int, start: Date?, end: Date?) {
        if let prayer, !settings.settings.privacyMode {
            updateRecords { $0.set(.prayed, for: prayer, on: start ?? Date(), rakahs: rakahs) }
        }
        if settings.settings.mindfulMinutes, !settings.settings.privacyMode, let start, let end {
            Task { await mindful.save(start: start, end: end) }
        }
    }

    func calmFeedback(helpful: Bool) {
        updateRecords { helpful ? ($0.calmHelpful += 1) : ($0.calmNotHelpful += 1) }
        anxiety.elevatedDelta = AppSession.calmDelta(notHelpful: records.calmNotHelpful)
    }

    /// Each "not helpful" makes reminders a little less eager (20 → 41 bpm max).
    nonisolated static func calmDelta(notHelpful: Int) -> Double { 20 + 3 * Double(min(notHelpful, 7)) }

    /// Clears history, journal, memorisation, calibration, saved mosques,
    /// favourites and wudu status. Settings are kept.
    func deleteAllData() {
        for key in Records.personalKeys { AppGroup.defaults.removeObject(forKey: key) }
        records = Records()
        wuduSince = nil
        lastPlan = []
        rescheduleAlertsIfNeeded()
        Task { await notifications.scheduleQadaReminder(false) }
    }

    // MARK: - Wudu status (manual)

    func setWudu(_ has: Bool) {
        wuduSince = has ? Date() : nil
        AppGroup.defaults.set(wuduSince, forKey: "wuduSince")
        lastPlan = []
        rescheduleAlertsIfNeeded()
    }

    // MARK: - Alerts

    /// Called once the method is chosen: the moment alerts become relevant.
    func prepareAlerts() async {
        if settings.settings.prayerAlerts {
            _ = await notifications.requestAuthorization()
        }
        alertsDenied = await notifications.isDenied()
        lastPlan = []
        rescheduleAlertsIfNeeded()
    }

    private func rescheduleAlertsIfNeeded() {
        guard settings.settings.hasChosenMethod, let coord = lastCoordinate else { return }
        let plan = AppSession.plan(at: coord, settings: settings.settings,
                                   mosque: nearestMosque.map { ($0.name, $0.distanceMeters) },
                                   hasWudu: wuduSince != nil)
        guard plan != lastPlan else { return }
        lastPlan = plan
        Task { await notifications.reschedule(plan) }
    }

    /// Three days of alerts from the given place and settings.
    nonisolated static func plan(at coord: CLLocationCoordinate2D,
                                 settings: PrayerSettings,
                                 mosque: (name: String, distanceMeters: Double)?,
                                 hasWudu: Bool = false) -> [PlannedAlert] {
        let now = Date()
        let tz = TimeZone.current
        let days = (0..<3).compactMap { offset -> DayTimetable? in
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: now) else { return nil }
            return PrayerEngine.timetable(on: day, at: coord, timeZone: tz, settings: settings)
        }
        return AlertPlanner.plan(timetables: days, settings: settings, now: now, mosque: mosque, hasWudu: hasWudu)
    }

    nonisolated static func backgroundRefresh() async {
        let settings = AppGroup.loadSettings()
        if settings.hasChosenMethod, let snap = SharedSnapshot.load() {
            let mosque = snap.mosqueName.flatMap { name in snap.mosqueDistanceMeters.map { (name, $0) } }
            let hasWudu = AppGroup.defaults.object(forKey: "wuduSince") != nil
            await NotificationScheduler().reschedule(plan(at: snap.coordinate, settings: settings, mosque: mosque, hasWudu: hasWudu))
        }
        WidgetCenter.shared.reloadAllTimelines()
        await MainActor.run { scheduleNextBackgroundRefresh() }
    }

    @MainActor static func scheduleNextBackgroundRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(6 * 3600), userInfo: nil
        ) { _ in }
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
        anxiety.elevatedDelta = AppSession.calmDelta(notHelpful: records.calmNotHelpful)
        for await signal in anxiety.stream(using: heart) {
            // Never during salah or khushu mode, and not while moving:
            // exercise raises heart rate too.
            guard signal == .elevated, activeSheet == nil, !salahActive,
                  !settings.settings.khushuMode, !(await recentlyMoving()) else { continue }
            activeSheet = .dhikr
            haptic.play(.dhikrReminder)
        }
    }

    private func recentlyMoving() async -> Bool {
        guard CMMotionActivityManager.isActivityAvailable() else { return false }
        return await withCheckedContinuation { cont in
            activity.queryActivityStarting(from: Date().addingTimeInterval(-180), to: Date(), to: .main) { acts, _ in
                let moving = (acts ?? []).contains { ($0.walking || $0.running || $0.cycling) && $0.confidence != .low }
                cont.resume(returning: moving)
            }
        }
    }

    // MARK: - Prayer times

    private func refreshLocationContext() async {
        for await coord in location.stream() {
            lastCoordinate = coord
            recomputePrayerTimes()
            nearestMosque = try? await mosques.nearest(to: coord)
            checkMosqueNudge()
            saveSnapshot()
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
        rescheduleAlertsIfNeeded()
    }

    /// Shares the latest place and mosque with widgets and background refresh.
    private func saveSnapshot() {
        guard let coord = lastCoordinate else { return }
        SharedSnapshot(latitude: coord.latitude, longitude: coord.longitude,
                       mosqueName: nearestMosque?.name,
                       mosqueDistanceMeters: nearestMosque?.distanceMeters,
                       updatedAt: Date()).save()
        WidgetCenter.shared.reloadAllTimelines()
        lastPlan = []
        rescheduleAlertsIfNeeded()
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
