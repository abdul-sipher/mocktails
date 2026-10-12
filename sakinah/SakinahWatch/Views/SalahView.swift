import SwiftUI

enum SalahMode: String, CaseIterable, Identifiable {
    case manual, automatic
    var id: String { rawValue }
    var title: String { self == .manual ? "Tap to count" : "Motion (experimental)" }
}

struct SalahStartView: View {
    @EnvironmentObject var session: AppSession
    /// nil = another prayer (sunnah, nafl) with a custom length.
    @State private var prayer: PrayerName? = .dhuhr
    @State private var rakahs = PrayerName.dhuhr.defaultRakahs
    @State private var mode: SalahMode = .manual
    @State private var seated = false

    var body: some View {
        List {
            Picker("Prayer", selection: $prayer) {
                ForEach(PrayerName.allCases) { p in
                    Text(p.title).tag(Optional(p))
                }
                Text("Other (sunnah, nafl)").tag(PrayerName?.none)
            }
            .onChange(of: prayer) { _, p in if let p { rakahs = session.settings.settings.defaultRakahs(for: p) } }

            Stepper(value: $rakahs, in: SalahTracker.rakahRange) {
                VStack(alignment: .leading) {
                    Text("\(rakahs) rakʿāt")
                    if session.settings.settings.travelling, let p = prayer, [.dhuhr, .asr, .isha].contains(p) {
                        Text("Shortened for travel").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Toggle("Praying seated", isOn: $seated)

            if !seated {
                Picker("Counting", selection: $mode) {
                    ForEach(SalahMode.allCases) { m in Text(m.title).tag(m) }
                }
            }

            NavigationLink {
                if seated || mode == .manual {
                    ManualSalahView(prayer: prayer, rakahs: rakahs)
                } else {
                    AutoSalahView(prayer: prayer ?? .dhuhr, rakahs: rakahs)
                }
            } label: {
                Text("Start").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .listRowBackground(Color.clear)

            Section {
                NavigationLink("Calibrate motion") { CalibrationView() }
            } footer: {
                Text(seated
                     ? "Seated prayer uses tap counting: wrist motion differs too much to read reliably."
                     : "Tap to count: tap the screen after each sajdah. Motion counting is experimental and can miss or misread postures.")
            }
        }
        .navigationTitle("Salah")
        .onAppear {
            let p = session.currentWindow?.prayer ?? prayer ?? .dhuhr
            prayer = p
            rakahs = session.settings.settings.defaultRakahs(for: p)
        }
    }
}

// MARK: - Manual

struct ManualSalahView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var tracker: SalahTracker
    @State private var showReview = false

    init(prayer: PrayerName?, rakahs: Int) {
        _tracker = StateObject(wrappedValue: SalahTracker(prayer: prayer, rakahCount: rakahs, haptics: nil))
    }

    var body: some View {
        Group {
            if tracker.status == .finished || showReview {
                SalahReviewView(tracker: tracker)
            } else if session.settings.settings.khushuMode {
                khushuView
            } else {
                trackingView
            }
        }
        .navigationTitle(tracker.prayer?.title ?? "Salah")
        .toolbar(session.settings.settings.khushuMode && tracker.status != .finished ? .hidden : .automatic, for: .navigationBar)
        .onAppear {
            tracker.configureHaptics(session.settings.settings.rakahHaptics ? session.haptic : nil)
            tracker.start()
            session.salahActive = true
        }
        .onDisappear {
            session.salahActive = false
            if tracker.status == .finished {
                session.salahFinished(prayer: tracker.prayer, rakahs: tracker.completedRakahs,
                                      start: tracker.startedAt, end: tracker.endedAt)
            }
        }
    }

    /// Khushu mode: a dark screen with one dim number; tap anywhere after each sajdah.
    private var khushuView: some View {
        Button {
            tracker.recordSajdah()
        } label: {
            VStack {
                Spacer()
                Text("\(tracker.currentRakah)")
                    .font(.system(size: 28, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.gray.opacity(0.5))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rakah \(tracker.currentRakah) of \(tracker.rakahCount), sajdah \(tracker.sajdah) of 2")
        .onLongPressGesture { tracker.finish() }
    }

    private var trackingView: some View {
        VStack(spacing: 6) {
            // The whole ring is the tap target: one tap after each sajdah.
            Button {
                tracker.recordSajdah()
            } label: {
                RakahRing(current: tracker.currentRakah, total: tracker.rakahCount, sajdah: tracker.sajdah)
                    .frame(width: 118, height: 118)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rakah \(tracker.currentRakah) of \(tracker.rakahCount), sajdah \(tracker.sajdah) of 2")
            .accessibilityHint("Double tap after each sajdah")
            .disabled(tracker.status != .running)

            Text(tracker.status == .paused ? "Paused" : "Tap after each sajdah")
                .font(.caption2).foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Button { tracker.undoSajdah() } label: { Image(systemName: "arrow.uturn.backward") }
                    .accessibilityLabel("Undo")
                Button {
                    tracker.status == .paused ? tracker.resume() : tracker.pause()
                } label: { Image(systemName: tracker.status == .paused ? "play.fill" : "pause.fill") }
                    .accessibilityLabel(tracker.status == .paused ? "Resume" : "Pause")
                Button { tracker.finish() } label: { Image(systemName: "checkmark") }
                    .accessibilityLabel("Finish")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Automatic (experimental)

struct AutoSalahView: View {
    let prayer: PrayerName
    @EnvironmentObject var session: AppSession
    @StateObject private var detector: SalahPostureDetector
    private let keeper = WorkoutSessionKeeper()
    @State private var awake = true

    init(prayer: PrayerName, rakahs: Int) {
        self.prayer = prayer
        let s = AppGroup.loadSettings()
        _detector = StateObject(wrappedValue: SalahPostureDetector(
            prayer: prayer, rakahCount: rakahs, haptic: HapticService(),
            hapticsOn: s.rakahHaptics, wrist: s.wrist, calibration: CalibrationProfile.load()))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("EXPERIMENTAL").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(.orange)
                RakahRing(current: detector.session.currentRakah, total: detector.session.rakahCount,
                          sajdah: detector.session.currentSajdah)
                    .frame(width: 100, height: 100)

                Text(postureLabel(detector.posture)).font(.headline)
                Text(detector.confidence >= SalahPostureDetector.minConfidence
                     ? "Sensor: steady"
                     : "Sensor unsure. Use + and − to correct.")
                    .font(.caption2)
                    .foregroundStyle(detector.confidence >= SalahPostureDetector.minConfidence ? Color.secondary : Color.orange)

                HStack(spacing: 6) {
                    Button {
                        detector.manuallyAdjustRakah(to: detector.session.currentRakah - 1)
                    } label: { Image(systemName: "minus") }
                    .accessibilityLabel("Remove")
                    Text("Rakah \(detector.session.currentRakah)/\(detector.session.rakahCount)")
                        .font(.caption2.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                    Button {
                        detector.manuallyAdjustRakah(to: detector.session.currentRakah + 1)
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                if detector.session.endedAt != nil {
                    NavigationLink { AdhkarView(set: .afterSalah) } label: {
                        Label("Adhkar after salah", systemImage: "circle.dotted")
                    }
                    .buttonStyle(.bordered)
                }
                if !awake {
                    Text("Health permission was not given, so the screen may sleep mid-prayer.")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(prayer.title)
        .task { awake = await keeper.start() }
        .onAppear {
            detector.start(stream: session.motion.stream())
            session.salahActive = true
        }
        .onDisappear {
            let s = detector.session
            detector.stop()
            keeper.stop()
            session.salahActive = false
            if let end = s.endedAt, s.currentRakah > 1 || s.currentSajdah > 0 {
                session.salahFinished(prayer: s.prayer, rakahs: s.currentRakah, start: s.startedAt, end: end)
            }
        }
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

// MARK: - Review

struct SalahReviewView: View {
    @ObservedObject var tracker: SalahTracker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                LabeledContent("Prayer", value: tracker.prayer?.title ?? "Other")
                if let d = tracker.duration {
                    LabeledContent("Time", value: Duration.seconds(d).formatted(.time(pattern: .minuteSecond)))
                }
                Stepper(value: Binding(get: { tracker.completedRakahs },
                                       set: { tracker.correctCompleted(to: $0) }),
                        in: 0...tracker.rakahCount) {
                    VStack(alignment: .leading) {
                        Text("\(tracker.completedRakahs) of \(tracker.rakahCount) rakʿāt")
                        Text("Correct if needed").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Review")
            }
            NavigationLink {
                AdhkarView(set: .afterSalah)
            } label: {
                Label("Adhkar after salah", systemImage: "circle.dotted")
            }
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent).tint(.green)
                .listRowBackground(Color.clear)
            Button("Pray again") { tracker.reset(); tracker.start() }
                .font(.caption)
        }
    }
}

// MARK: - Shared ring

struct RakahRing: View {
    let current: Int
    let total: Int
    var sajdah: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(current) / CGFloat(max(total, 1)))
                .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut, value: current)
            VStack(spacing: 0) {
                Text("\(current)").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("of \(total)").font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(1...2, id: \.self) { i in
                        Circle().fill(i <= sajdah ? Color.orange : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 2)
                .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Calibration

/// Records the user's average wrist orientation in four postures.
/// Only the averages are stored; the raw samples are discarded.
struct CalibrationView: View {
    @EnvironmentObject var session: AppSession
    @State private var step = -1          // -1 = consent screen
    @State private var recorded: [Posture: CalibrationProfile.Point] = [:]
    @State private var samples: [CalibrationProfile.Point] = []
    @State private var recording = false
    @State private var hasProfile = CalibrationProfile.load() != nil

    private let seconds = 5

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if step < 0 {
                    Text("Calibrate motion").font(.headline)
                    Text("Wear the watch as you do for prayer. You'll hold standing, bowing, prostration and sitting for \(seconds) seconds each. Only the average position is saved on this watch; nothing is uploaded.")
                        .font(.caption2).multilineTextAlignment(.center)
                    if session.motion.isAvailable {
                        Button("Begin") { step = 0 }.buttonStyle(.borderedProminent).tint(.green)
                    } else {
                        Text("Motion sensors are not available on this device.")
                            .font(.caption2).foregroundStyle(.orange).multilineTextAlignment(.center)
                    }
                    if hasProfile {
                        Button("Delete calibration", role: .destructive) {
                            CalibrationProfile.delete()
                            hasProfile = false
                        }
                        .font(.caption)
                    }
                } else if step < CalibrationProfile.postures.count {
                    let posture = CalibrationProfile.postures[step]
                    Text("Step \(step + 1) of \(CalibrationProfile.postures.count)").font(.caption2).foregroundStyle(.secondary)
                    Text(title(posture)).font(.headline)
                    Text(recording ? "Hold still…" : "Get into position, then tap Record. The watch buzzes when done.")
                        .font(.caption2).multilineTextAlignment(.center)
                    Button(recording ? "Recording" : "Record") { record(posture) }
                        .buttonStyle(.borderedProminent).tint(.green)
                        .disabled(recording)
                } else {
                    Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.green)
                    Text("Calibrated").font(.headline)
                    Text("Motion counting now uses your own positions.").font(.caption2)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Calibrate")
    }

    private func title(_ p: Posture) -> String {
        switch p {
        case .qiyam: return "Stand, hands folded"
        case .ruku: return "Bow (rukūʿ)"
        case .sujood: return "Prostrate (sujūd)"
        default: return "Sit (jalsa)"
        }
    }

    private func record(_ posture: Posture) {
        recording = true
        samples = []
        Task {
            let stream = session.motion.stream()
            let deadline = Date().addingTimeInterval(TimeInterval(seconds))
            for await s in stream {
                samples.append(.init(gx: s.gravityX, gy: s.gravityY, gz: s.gravityZ))
                if Date() >= deadline { break }
            }
            recording = false
            session.haptic.play(.lightTick)
            if let mean = CalibrationProfile.Point.mean(samples) { recorded[posture] = mean }
            samples = []
            step += 1
            if step == CalibrationProfile.postures.count, recorded.count == CalibrationProfile.postures.count {
                CalibrationProfile(points: recorded, recordedAt: Date()).save()
                hasProfile = true
            }
        }
    }
}
