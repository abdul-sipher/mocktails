import Foundation
import Combine

/// Haptics the tracker asks for; `HapticService` plays them on the watch.
protocol SalahHaptics {
    func tick()
    /// N buzzes after rakah N (requested behaviour; do not change).
    func rakahCompleted(_ rakah: Int)
}

/// Manual salah tracking: one tap per sajdah; the second sajdah
/// completes the rakah. Works with no sensors at all.
@MainActor
final class SalahTracker: ObservableObject {
    enum Status: Equatable { case ready, running, paused, finished }

    let prayer: PrayerName?
    @Published private(set) var rakahCount: Int
    @Published private(set) var status: Status = .ready
    @Published private(set) var currentRakah = 1
    /// Sajdahs done in the current rakah: 0, 1 or 2.
    @Published private(set) var sajdah = 0
    @Published private(set) var completedRakahs = 0
    @Published private(set) var startedAt: Date?
    @Published private(set) var endedAt: Date?

    private var haptics: SalahHaptics?

    static let rakahRange = 1...12

    /// `haptics` nil = buzzes switched off in Settings.
    init(prayer: PrayerName?, rakahCount: Int, haptics: SalahHaptics?) {
        self.prayer = prayer
        self.rakahCount = min(max(rakahCount, Self.rakahRange.lowerBound), Self.rakahRange.upperBound)
        self.haptics = haptics
    }

    /// Set from Settings when the screen appears; nil = silent.
    func configureHaptics(_ haptics: SalahHaptics?) { self.haptics = haptics }

    func start(at date: Date = Date()) {
        guard status == .ready else { return }
        status = .running
        startedAt = date
    }

    func pause() { if status == .running { status = .paused } }
    func resume() { if status == .paused { status = .running } }

    func finish(at date: Date = Date()) {
        guard status == .running || status == .paused else { return }
        status = .finished
        endedAt = date
    }

    func reset() {
        status = .ready
        currentRakah = 1
        sajdah = 0
        completedRakahs = 0
        startedAt = nil
        endedAt = nil
    }

    /// Tap after each sajdah.
    func recordSajdah() {
        guard status == .running else { return }
        sajdah += 1
        if sajdah >= 2 {
            completeRakah()
        } else {
            haptics?.tick()
        }
    }

    func undoSajdah() {
        guard status == .running || status == .paused else { return }
        if sajdah > 0 {
            sajdah -= 1
        } else if completedRakahs > 0, currentRakah > 1 {
            currentRakah -= 1
            completedRakahs = currentRakah - 1
            sajdah = 1
        }
    }

    /// ± correction during or after prayer.
    func adjustRakah(by delta: Int) {
        currentRakah = min(max(currentRakah + delta, 1), rakahCount)
        completedRakahs = status == .finished ? currentRakah : currentRakah - 1
        sajdah = 0
    }

    /// Post-prayer review: set the number of rakahs actually prayed.
    func correctCompleted(to value: Int) {
        completedRakahs = min(max(value, 0), rakahCount)
    }

    var duration: TimeInterval? {
        guard let startedAt else { return nil }
        return (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    private func completeRakah() {
        completedRakahs = currentRakah
        haptics?.rakahCompleted(currentRakah)
        if currentRakah >= rakahCount {
            finish()
        } else {
            currentRakah += 1
            sajdah = 0
        }
    }
}
