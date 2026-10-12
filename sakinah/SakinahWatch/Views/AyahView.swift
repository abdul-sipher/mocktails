import SwiftUI

/// Qur'an: a verse for the moment, plus memorisation.
struct AyahView: View {
    @EnvironmentObject var session: AppSession
    @State private var ayah: Ayah?

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 10) {
                if let ayah {
                    Text(ayah.arabic)
                        .font(.system(size: 22, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .rightToLeft)
                    Text(ayah.translation)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(ayah.surahName) · \(ayah.surah):\(ayah.number)\(ayah.excerpt == true ? " · excerpt" : "")")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ProgressView()
                }
                Button("Another") { reshuffle() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Text("A suggested verse for this time of day, not a prescribed practice.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                NavigationLink {
                    MemorisationView()
                } label: {
                    Label("Memorise", systemImage: "brain.head.profile").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Qurʾan")
        .onAppear { ayah = session.quran.ayahForCurrentHour() }
    }

    private func reshuffle() { ayah = session.quran.ayahForCurrentHour() }
}

struct MemorisationView: View {
    @State private var plan = MemorisationPlan.load()

    var body: some View {
        List {
            Section {
                Picker("Surah", selection: Binding(get: { plan.surah }, set: { plan.choose($0); plan.save() })) {
                    ForEach(Surah.memorisable) { s in Text("\(s.number). \(s.name)").tag(s) }
                }
                Stepper(value: Binding(get: { plan.dailyTarget }, set: { plan.dailyTarget = $0; plan.save() }), in: 1...10) {
                    Text("\(plan.dailyTarget) āyāt a day")
                }
                ProgressView(value: Double(plan.memorisedAyat), total: Double(plan.surah.ayat)) {
                    Text("\(plan.memorisedAyat) of \(plan.surah.ayat) āyāt").font(.caption2)
                }
                .tint(.green)
                Button(plan.loggedToday() ? "Done today ✓" : "I did today's āyāt") {
                    plan.logToday(); plan.save()
                }
                .disabled(plan.loggedToday() || plan.isComplete)
                if plan.streak > 0 {
                    Text("\(plan.streak)-day streak").font(.caption2).foregroundStyle(.green)
                }
            } header: {
                Text("Today")
            }
            if let rev = plan.nextRevision {
                Section("Revise") {
                    Button("Revised \(rev.name)") { plan.markRevised(rev); plan.save() }
                    Text("Longest since you last went over it.").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Memorise")
    }
}
