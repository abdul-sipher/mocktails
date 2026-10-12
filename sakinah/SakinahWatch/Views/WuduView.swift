import SwiftUI

struct WuduView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var detector: WuduStepDetector

    init() {
        _detector = StateObject(wrappedValue: WuduStepDetector(haptic: HapticService()))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if detector.completed {
                    completedView
                } else {
                    progressView
                }
                Divider()
                NavigationLink {
                    GhuslChecklistView()
                } label: {
                    Label("Ghusl checklist", systemImage: "drop.triangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Wudu")
        .onAppear { detector.start(stream: session.motion.stream()) }
        .onDisappear { detector.stop() }
    }

    private var progressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(detector.currentStep.rawValue), total: Double(WuduStep.allCases.count))
                .tint(.teal)
                .accessibilityLabel("Step \(detector.currentStep.rawValue + 1) of \(WuduStep.allCases.count)")
            Text(detector.currentStep.arabicHint)
                .font(.system(size: 22, weight: .medium))
                .environment(\.layoutDirection, .rightToLeft)
            Text(detector.currentStep.title)
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            RepCounter(current: detector.repetitions, target: detector.currentStep.target)

            HStack {
                Button("Skip") { detector.advance() }
                    .buttonStyle(.bordered).tint(.gray)
                Button("Next") { detector.advance() }
                    .buttonStyle(.borderedProminent).tint(.teal)
            }
            .font(.caption)

            Button("Start again", role: .destructive) { detector.reset() }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

            Text("Motion counting is experimental. Tap Next whenever it misses a wash.")
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var completedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.teal)
            Text("Wudu complete").font(.headline)
            Text("أَشْهَدُ أَنْ لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ")
                .font(.footnote).multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
            Text("I bear witness that there is no god but Allah alone, without partner, and that Muhammad is His servant and Messenger. (Sahih Muslim 234)")
                .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)

            if session.wuduSince == nil {
                Button("Mark: I have wudu") { session.setWudu(true) }
                    .buttonStyle(.borderedProminent).tint(.teal)
            } else {
                Label("Marked", systemImage: "checkmark").font(.caption).foregroundStyle(.teal)
            }
            Button("Start again") { detector.reset() }
                .font(.caption2).buttonStyle(.plain).foregroundStyle(.secondary)
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
        .accessibilityElement()
        .accessibilityLabel("\(current) of \(target)")
    }
}

/// The Prophet's ghusl as described by ʿAishah and Maymunah. Guidance
/// for scholar review before release.
struct GhuslChecklistView: View {
    @State private var done: Set<Int> = []

    private let steps = [
        "Make the intention (niyyah) for ghusl.",
        "Wash both hands.",
        "Wash the private parts with the left hand.",
        "Make wudu as for prayer.",
        "Run wet fingers through the roots of the hair.",
        "Pour water over the head three times.",
        "Pour water over the whole body, right side then left.",
        "Make sure water reaches every part of the body.",
        "Wash the feet, moving aside if water has pooled."
    ]

    var body: some View {
        List {
            ForEach(steps.indices, id: \.self) { i in
                Button {
                    if done.contains(i) { done.remove(i) } else { done.insert(i) }
                } label: {
                    HStack(alignment: .top) {
                        Image(systemName: done.contains(i) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done.contains(i) ? .teal : .secondary)
                        Text(steps[i]).font(.footnote)
                    }
                }
                .accessibilityAddTraits(done.contains(i) ? .isSelected : [])
            }
            Section {
                Text("Sahih al-Bukhari 248, 249; Sahih Muslim 316, 317. Which parts are obligatory differs by madhhab: Hanafis, for example, hold that rinsing the mouth and nose is obligatory in ghusl.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Button("Clear ticks") { done.removeAll() }
                .font(.caption)
        }
        .navigationTitle("Ghusl")
    }
}
