import Foundation

/// Tracks progression through the steps of wudu by watching for a
/// repeated washing gesture: forearm pronate/supinate oscillation
/// combined with elevated user-acceleration variance.
///
/// Each step expects either a sustained hold (niyyah) or three
/// gesture repetitions (washing steps). Users can tap to advance
/// manually if the detector disagrees.
@MainActor
final class WuduStepDetector: ObservableObject {
    @Published private(set) var currentStep: WuduStep = .niyyah
    @Published private(set) var repetitions: Int = 0
    @Published private(set) var completed: Bool = false

    private let haptic: HapticService
    private var task: Task<Void, Never>?
    private var lastGestureAt: Date = .distantPast
    private var gestureBudget: [WuduStep: Int] = [
        .handsThrice: 3, .mouthThrice: 3, .noseThrice: 3,
        .faceThrice: 3, .armsThrice: 3, .feetThrice: 3,
        .headWipe: 1, .earsWipe: 1
    ]

    init(haptic: HapticService) { self.haptic = haptic }

    func start(stream: AsyncStream<MotionService.Sample>) {
        task = Task { [weak self] in
            for await sample in stream {
                await self?.ingest(sample)
                if Task.isCancelled { break }
            }
        }
    }

    func stop() { task?.cancel(); task = nil }

    func advance() {
        guard let next = WuduStep(rawValue: currentStep.rawValue + 1) else {
            completed = true
            haptic.play(.wuduComplete)
            return
        }
        currentStep = next
        repetitions = 0
        haptic.play(.postureChange)
    }

    private func ingest(_ s: MotionService.Sample) {
        // Niyyah is a still hold — auto-advance after 4 seconds at rest.
        if currentStep == .niyyah {
            if s.userAccelMag < 0.05 && s.rotationMag < 0.3 {
                if lastGestureAt == .distantPast { lastGestureAt = Date() }
                if Date().timeIntervalSince(lastGestureAt) > 4 { advance() }
            } else {
                lastGestureAt = .distantPast
            }
            return
        }

        // Washing gesture: rapid oscillation (high rotationMag) with
        // bursts of userAccel > 0.25g, separated by brief pauses.
        let isGesturePeak = s.rotationMag > 3.5 && s.userAccelMag > 0.25
        let now = Date()
        if isGesturePeak && now.timeIntervalSince(lastGestureAt) > 0.8 {
            lastGestureAt = now
            repetitions += 1
            haptic.play(.lightTick)
            let budget = gestureBudget[currentStep] ?? 1
            if repetitions >= budget { advance() }
        }
    }
}
