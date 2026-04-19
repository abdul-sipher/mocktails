import SwiftUI

struct WuduView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var detector: WuduStepDetector

    init() {
        _detector = StateObject(wrappedValue: WuduStepDetector(haptic: HapticService()))
    }

    var body: some View {
        VStack(spacing: 8) {
            if detector.completed {
                completedView
            } else {
                progressView
            }
        }
        .padding()
        .navigationTitle("Wudu")
        .onAppear { detector.start(stream: session.motion.stream()) }
        .onDisappear { detector.stop() }
    }

    private var progressView: some View {
        VStack(spacing: 10) {
            Text(detector.currentStep.arabicHint)
                .font(.system(size: 22, weight: .medium))
            Text(detector.currentStep.title)
                .font(.footnote).foregroundStyle(.secondary)

            RepCounter(current: detector.repetitions, target: target(for: detector.currentStep))

            HStack {
                Button("Skip") { detector.advance() }
                    .buttonStyle(.bordered).tint(.gray)
                Button("Next") { detector.advance() }
                    .buttonStyle(.borderedProminent).tint(.teal)
            }
            .font(.caption)
        }
    }

    private var completedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.teal)
            Text("Wudu complete").font(.headline)
            Text("أشهد أن لا إله إلا الله وأشهد أن محمدا رسول الله")
                .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
    }

    private func target(for step: WuduStep) -> Int {
        switch step {
        case .headWipe, .earsWipe, .niyyah: return 1
        default: return 3
        }
    }
}

private struct RepCounter: View {
    let current: Int
    let target: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<target, id: \.self) { i in
                Circle()
                    .fill(i < current ? Color.teal : Color.secondary.opacity(0.25))
                    .frame(width: 14, height: 14)
            }
        }
    }
}
