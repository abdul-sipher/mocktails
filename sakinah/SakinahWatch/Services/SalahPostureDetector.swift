import Foundation
import Combine

/// Classifies wrist-motion samples into salah postures and drives a
/// rakah/sajdah counter through the canonical cycle:
///
///   qiyam → ruku → qawmah → sujood → jalsa → sujood → (next rakah)
///
/// Heuristics (left-wrist worn; thresholds are first-pass defaults
/// and are intended to be user-calibrated). Gravity is a unit vector
/// in the device frame, so components reveal which way the wrist
/// points relative to vertical.
@MainActor
final class SalahPostureDetector: ObservableObject {
    @Published private(set) var session: SalahSession
    @Published private(set) var posture: Posture = .idle

    private let haptic: HapticService
    private var lastPosture: Posture = .idle
    private var postureEnteredAt: Date = .distantPast
    private var altitudeBaseline: Double?
    private var rukuSeenThisRakah = false
    private var sujoodCountThisRakah = 0
    private var task: Task<Void, Never>?

    init(prayer: PrayerName, haptic: HapticService) {
        self.session = SalahSession(prayer: prayer, rakahCount: prayer.defaultRakahs)
        self.haptic = haptic
    }

    func start(stream: AsyncStream<MotionService.Sample>) {
        task = Task { [weak self] in
            for await sample in stream {
                await self?.ingest(sample)
                if Task.isCancelled { break }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        session.endedAt = Date()
    }

    // MARK: - Classification

    private func ingest(_ s: MotionService.Sample) {
        if altitudeBaseline == nil { altitudeBaseline = s.relativeAltitude }
        let altDelta = s.relativeAltitude - (altitudeBaseline ?? 0)
        let candidate = classify(sample: s, altitudeDelta: altDelta)
        let stable = stabilize(candidate)

        guard stable != posture else { return }
        transition(to: stable)
    }

    private func classify(sample s: MotionService.Sample, altitudeDelta: Double) -> Posture {
        // Gravity Z ≈ -1 means screen points up (wrist face-up on the ground → sujood).
        // Gravity Z ≈  0 means wrist is roughly vertical (ruku pose, arms on knees).
        // Gravity Y negative means forearm horizontal with screen toward body (qiyam).
        //
        // Altitude delta < ~-0.2 m: wrist dropped near floor → strong sujood signal.
        let gy = s.gravityY
        let gz = s.gravityZ
        let still = s.userAccelMag < 0.08 && s.rotationMag < 0.6

        if altitudeDelta < -0.18 && gz < -0.75 && still {
            return .sujood
        }
        if gz < -0.6 && abs(gy) < 0.5 && still {
            return .sujood
        }
        // Ruku: wrist low, forearm roughly horizontal but chest bent forward → gy ≈ -0.8.
        if gy < -0.7 && abs(gz) < 0.45 && altitudeDelta < -0.05 && still {
            return .ruku
        }
        // Qiyam: standing, hands folded over chest, forearm horizontal, palm inward.
        if gy < -0.55 && gz > -0.3 && altitudeDelta > -0.08 && still {
            return .qiyam
        }
        // Jalsa / tashahhud: sitting, forearm on thigh, altitude mid.
        if abs(gy) < 0.4 && gz > 0.3 && still {
            return posture == .sujood ? .jalsa : .jalsa
        }
        // Qawmah: transient upright after ruku.
        if gy < -0.4 && altitudeDelta > -0.08 && still {
            return .qawmah
        }
        return posture
    }

    /// Require a posture to be held for >= 600ms before accepting it,
    /// which filters out transient classifications during transitions.
    private func stabilize(_ candidate: Posture) -> Posture {
        let now = Date()
        if candidate != lastPosture {
            lastPosture = candidate
            postureEnteredAt = now
            return posture
        }
        if now.timeIntervalSince(postureEnteredAt) >= 0.6 {
            return candidate
        }
        return posture
    }

    private func transition(to new: Posture) {
        let previous = posture
        posture = new
        session.currentPosture = new

        switch (previous, new) {
        case (_, .ruku):
            rukuSeenThisRakah = true
            haptic.play(.postureChange)

        case (_, .sujood):
            sujoodCountThisRakah += 1
            session.currentSajdah = sujoodCountThisRakah
            haptic.play(sujoodCountThisRakah == 1 ? .sajdahOne : .sajdahTwo)

        case (.sujood, .qiyam), (.jalsa, .qiyam):
            // New rakah begins on return to standing after two sujoods.
            if sujoodCountThisRakah >= 2 {
                advanceRakah()
            }

        case (_, .tashahhud):
            haptic.play(.postureChange)

        default:
            haptic.play(.postureChange)
        }
    }

    private func advanceRakah() {
        guard session.currentRakah < session.rakahCount else {
            haptic.play(.salahComplete)
            session.endedAt = Date()
            return
        }
        session.currentRakah += 1
        session.currentSajdah = 0
        sujoodCountThisRakah = 0
        rukuSeenThisRakah = false
        haptic.play(.rakahComplete)
    }

    // MARK: - Manual override (for forgetful moments)

    func manuallyAdjustRakah(to value: Int) {
        session.currentRakah = max(1, min(value, session.rakahCount))
        session.currentSajdah = 0
        sujoodCountThisRakah = 0
    }
}
