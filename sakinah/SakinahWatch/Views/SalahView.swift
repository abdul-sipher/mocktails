import SwiftUI

struct SalahStartView: View {
    @EnvironmentObject var session: AppSession
    @State private var selected: PrayerName = .dhuhr

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Begin Salah").font(.headline)
                Picker("Prayer", selection: $selected) {
                    ForEach(PrayerName.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
                .pickerStyle(.navigationLink)

                Text("\(selected.defaultRakahs) rakʿāt")
                    .font(.caption).foregroundStyle(.secondary)

                NavigationLink {
                    SalahLiveView(prayer: selected)
                } label: {
                    Text("Start").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
        }
        .navigationTitle("Salah")
    }
}

struct SalahLiveView: View {
    let prayer: PrayerName
    @EnvironmentObject var session: AppSession
    @StateObject private var detector: SalahPostureDetector

    init(prayer: PrayerName) {
        self.prayer = prayer
        _detector = StateObject(wrappedValue: SalahPostureDetector(prayer: prayer, haptic: HapticService()))
    }

    var body: some View {
        VStack(spacing: 8) {
            RakahRing(current: detector.session.currentRakah, total: detector.session.rakahCount)
                .frame(width: 110, height: 110)

            Text(postureLabel(detector.posture))
                .font(.headline)

            if detector.posture == .sujood {
                Text("Sajdah \(detector.session.currentSajdah)")
                    .font(.subheadline).foregroundStyle(.orange)
            }

            HStack(spacing: 6) {
                Button {
                    detector.manuallyAdjustRakah(to: detector.session.currentRakah - 1)
                } label: { Image(systemName: "minus") }
                Text("Rakah \(detector.session.currentRakah) / \(detector.session.rakahCount)")
                    .font(.caption.monospacedDigit())
                Button {
                    detector.manuallyAdjustRakah(to: detector.session.currentRakah + 1)
                } label: { Image(systemName: "plus") }
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding()
        .navigationTitle(prayer.title)
        .onAppear { detector.start(stream: session.motion.stream()) }
        .onDisappear { detector.stop() }
    }

    private func postureLabel(_ p: Posture) -> String {
        switch p {
        case .idle:      return "—"
        case .qiyam:     return "Qiyām"
        case .ruku:      return "Rukūʿ"
        case .qawmah:    return "Qawmah"
        case .sujood:    return "Sujūd"
        case .jalsa:     return "Jalsa"
        case .tashahhud: return "Tashahhud"
        }
    }
}

private struct RakahRing: View {
    let current: Int
    let total: Int

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(current) / CGFloat(max(total, 1)))
                .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: current)
            VStack(spacing: 0) {
                Text("\(current)").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("of \(total)").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
