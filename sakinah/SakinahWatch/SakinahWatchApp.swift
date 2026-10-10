import SwiftUI
import CoreLocation

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

@MainActor
final class AppSession: ObservableObject {
    let motion = MotionService()
    let heart = HeartRateService()
    let anxiety = AnxietyDetector()
    let location = LocationService()
    let mosques = MosqueFinder()
    let prayerTimes = PrayerTimesService()
    let quran = QuranService()
    let haptic = HapticService()

    @Published var nearestMosque: Mosque?
    @Published var nextPrayer: PrayerTime?
    @Published var currentAyah: Ayah?
    @Published var dhikrReminderActive = false
    /// True while the next prayer is ≤ 10 min away and a mosque is known.
    @Published var mosqueNudgeActive = false

    /// Latest fix. Screens read this rather than calling location.stream(),
    /// which only supports one listener.
    @Published private(set) var lastCoordinate: CLLocationCoordinate2D?
    /// Prayer window already nudged, so the haptic plays once per prayer.
    private var nudgedPrayerDate: Date?

    func bootstrap() async {
        await heart.requestAuthorization()
        location.requestAuthorization()

        Task { await observeAnxiety() }
        Task { await refreshLocationContext() }
        Task { await refreshAyahTimer() }
        Task { await refreshPrayerWindow() }
    }

    private func observeAnxiety() async {
        for await signal in anxiety.stream(using: heart) {
            guard signal == .elevated else { continue }
            dhikrReminderActive = true
            haptic.play(.dhikrReminder)
        }
    }

    private func refreshLocationContext() async {
        for await coord in location.stream() {
            lastCoordinate = coord
            nearestMosque = try? await mosques.nearest(to: coord)
            nextPrayer = prayerTimes.next(at: coord)
            checkMosqueNudge()
        }
    }

    /// Location updates only arrive on movement, so recheck the clock
    /// regularly to roll over to the next prayer and open the nudge window.
    private func refreshPrayerWindow() async {
        while !Task.isCancelled {
            if let coord = lastCoordinate {
                nextPrayer = prayerTimes.next(at: coord)
                checkMosqueNudge()
            }
            try? await Task.sleep(for: .seconds(30))
        }
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
