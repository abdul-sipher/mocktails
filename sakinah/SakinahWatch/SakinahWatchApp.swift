import SwiftUI

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

    func bootstrap() async {
        await heart.requestAuthorization()
        location.requestAuthorization()

        Task { await observeAnxiety() }
        Task { await refreshLocationContext() }
        Task { await refreshAyahTimer() }
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
            nearestMosque = try? await mosques.nearest(to: coord)
            nextPrayer = prayerTimes.next(at: coord)
        }
    }

    private func refreshAyahTimer() async {
        while !Task.isCancelled {
            currentAyah = quran.ayahForCurrentHour()
            try? await Task.sleep(for: .seconds(60 * 30))
        }
    }
}
