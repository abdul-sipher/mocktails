import Foundation

/// Emits an `.elevated` signal when the user's heart rate stays
/// meaningfully above their resting baseline while HRV (SDNN) drops,
/// a combination associated with sympathetic arousal / anxiety.
///
/// This is a heuristic, not a diagnosis — the user can silence it or
/// adjust sensitivity. The goal is a gentle nudge: "Remember Allah
/// and your heart finds rest" (Qur'an 13:28).
@MainActor
final class AnxietyDetector {
    enum Signal { case normal, elevated }

    /// How far above rolling-baseline HR counts as elevated (bpm).
    var elevatedDelta: Double = 20
    /// HRV below this is considered suppressed (ms, SDNN).
    var hrvFloor: Double = 30
    /// Cooldown before re-emitting `.elevated`.
    var cooldown: TimeInterval = 15 * 60

    private var baseline: Double = 70
    private var lastElevatedAt: Date = .distantPast

    func stream(using heart: HeartRateService) -> AsyncStream<Signal> {
        AsyncStream { continuation in
            Task {
                var rolling: [Double] = []
                for await reading in heart.stream() {
                    rolling.append(reading.bpm)
                    if rolling.count > 60 { rolling.removeFirst() }
                    if rolling.count >= 10 {
                        baseline = rolling.sorted()[rolling.count / 4]  // 25th percentile
                    }

                    let hrv = await heart.latestHRV() ?? .infinity
                    let elevated =
                        reading.bpm > baseline + elevatedDelta &&
                        hrv < hrvFloor
                    if elevated {
                        let now = Date()
                        if now.timeIntervalSince(lastElevatedAt) > cooldown {
                            lastElevatedAt = now
                            continuation.yield(.elevated)
                        }
                    }
                }
            }
        }
    }
}
