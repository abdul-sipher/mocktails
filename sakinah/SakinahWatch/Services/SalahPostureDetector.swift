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
    /// 0…1: how consistently recent samples agree. Below `minConfidence`
    /// the detector holds its last posture rather than guess.
    @Published private(set) var confidence: Double = 0

    static let minConfidence = 0.5

    private let haptic: HapticService
    private let hapticsOn: Bool
    private let wrist: Wrist
    private let calibration: CalibrationProfile?
    private var recent: [Posture] = []
    private var lastPosture: Posture = .idle
    private var postureEnteredAt: Date = .distantPast
    private var altitudeBaseline: Double?
    private var rukuSeenThisRakah = false
    private var sujoodCountThisRakah = 0
    private var task: Task<Void, Never>?

    init(prayer: PrayerName, rakahCount: Int? = nil, haptic: HapticService,
         hapticsOn: Bool = true, wrist: Wrist = .left, calibration: CalibrationProfile? = nil) {
        self.session = SalahSession(prayer: prayer, rakahCount: rakahCount ?? prayer.defaultRakahs)
        self.haptic = haptic
        self.hapticsOn = hapticsOn
        self.wrist = wrist
        self.calibration = calibration
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
        let (candidate, sampleConfidence) = classifyWithConfidence(sample: s, altitudeDelta: altDelta)
        recent.append(candidate)
        if recent.count > 25 { recent.removeFirst() }
        let agreement = Double(recent.filter { $0 == candidate }.count) / Double(recent.count)
        confidence = min(agreement, sampleConfidence)
        guard confidence >= Self.minConfidence else { return }
        let stable = stabilize(candidate)

        guard stable != posture else { return }
        transition(to: stable)
    }

    /// Calibrated profile when recorded, otherwise the default thresholds.
    private func classifyWithConfidence(sample s: MotionService.Sample, altitudeDelta: Double) -> (Posture, Double) {
        let gy = wrist == .right ? -s.gravityY : s.gravityY
        if let calibration {
            // Calibration was recorded on this wrist, so compare raw values.
            let point = CalibrationProfile.Point(gx: s.gravityX, gy: s.gravityY, gz: s.gravityZ)
            guard let hit = calibration.classify(point) else { return (posture, 0) }
            var p = hit.posture
            // Sitting is told apart by rakah state, not motion.
            if p == .jalsa, sujoodCountThisRakah >= 2,
               session.currentRakah == 2 || session.currentRakah == session.rakahCount {
                p = .tashahhud
            }
            return (p, hit.confidence)
        }
        return (classify(sample: s, gravityY: gy, altitudeDelta: altitudeDelta), 1)
    }

    private func classify(sample s: MotionService.Sample, gravityY: Double, altitudeDelta: Double) -> Posture {
        // Gravity Z ≈ -1 means screen points up (wrist face-up on the ground → sujood).
        // Gravity Z ≈  0 means wrist is roughly vertical (ruku pose, arms on knees).
        // Gravity Y negative means forearm horizontal with screen toward body (qiyam).
        //
        // Altitude delta < ~-0.2 m: wrist dropped near floor → strong sujood signal.
        let gy = gravityY
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
        // Same wrist pose for both; rakah state tells them apart. After both
        // sujoods of rakah 2 (middle sitting) or of the final rakah, it is tashahhud.
        if abs(gy) < 0.4 && gz > 0.3 && still {
            let tashahhudRakah = session.currentRakah == 2 || session.currentRakah == session.rakahCount
            return sujoodCountThisRakah >= 2 && tashahhudRakah ? .tashahhud : .jalsa
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
            if hapticsOn { haptic.play(.postureChange) }

        case (_, .sujood):
            sujoodCountThisRakah += 1
            session.currentSajdah = sujoodCountThisRakah
            if hapticsOn { haptic.play(sujoodCountThisRakah == 1 ? .sajdahOne : .sajdahTwo) }

        case (.sujood, .qiyam), (.jalsa, .qiyam), (.tashahhud, .qiyam):
            // New rakah begins on return to standing after two sujoods.
            if sujoodCountThisRakah >= 2 {
                advanceRakah()
            }

        case (_, .tashahhud):
            if hapticsOn { haptic.play(.postureChange) }

        default:
            if hapticsOn { haptic.play(.postureChange) }
        }
    }

    private func advanceRakah() {
        let completed = session.currentRakah
        if hapticsOn { haptic.playRakahCount(completed) }

        if completed >= session.rakahCount {
            session.endedAt = Date()
            return
        }
        session.currentRakah += 1
        session.currentSajdah = 0
        sujoodCountThisRakah = 0
        rukuSeenThisRakah = false
    }

    // MARK: - Manual override (for forgetful moments)

    func manuallyAdjustRakah(to value: Int) {
        session.currentRakah = max(1, min(value, session.rakahCount))
        session.currentSajdah = 0
        sujoodCountThisRakah = 0
    }
}
