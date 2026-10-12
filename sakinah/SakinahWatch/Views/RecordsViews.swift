import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        List {
            Section {
                ForEach(PrayerName.allCases) { p in
                    row(p)
                }
            } header: {
                Text("Today")
            } footer: {
                if session.settings.settings.privacyMode {
                    Text("Privacy mode is on: salah sessions are not recorded. Ticks you set here are still saved.")
                }
            }

            Section {
                LabeledContent("Owed", value: "\(session.records.qadaOwed)")
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("qada-owed")
                Button("Made up one") { session.updateRecords { $0.madeUpOne() } }
                    .disabled(session.records.qadaOwed == 0)
                Stepper("Adjust", value: Binding(get: { session.records.qadaOwed },
                                                 set: { v in session.updateRecords { $0.qadaOwed = max(0, v) } }),
                        in: 0...9999)
            } header: {
                Text("Missed prayers (qada)")
            } footer: {
                Text("Marking a prayer missed adds one. Only you can see this.")
            }

            Section {
                let streak = session.records.fullDayStreak()
                LabeledContent("All five prayed", value: streak == 1 ? "1 day" : "\(streak) days")
                NavigationLink { JournalView() } label: { Label("Gratitude journal", systemImage: "book.closed") }
            }
        }
        .navigationTitle("History")
    }

    private func row(_ p: PrayerName) -> some View {
        let status = session.records.record(for: p, on: Date())?.status
        return HStack {
            Text(p.displayTitle(isFriday: session.timetable?.isFriday ?? false))
            Spacer()
            Button {
                session.updateRecords { $0.set(status == .prayed ? nil : .prayed, for: p, on: Date()) }
            } label: {
                Image(systemName: status == .prayed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(status == .prayed ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(p.title) prayed")
            .accessibilityAddTraits(status == .prayed ? .isSelected : [])
            Button {
                session.updateRecords { $0.set(status == .missed ? nil : .missed, for: p, on: Date()) }
            } label: {
                Image(systemName: status == .missed ? "xmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(status == .missed ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(p.title) missed")
            .accessibilityAddTraits(status == .missed ? .isSelected : [])
        }
    }
}

struct JournalView: View {
    @EnvironmentObject var session: AppSession
    @State private var draft = ""

    var body: some View {
        List {
            Section {
                TextField("Something you're grateful for", text: $draft)
                Button("Save") {
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    session.updateRecords { $0.journal.insert(JournalEntry(text: text, date: Date()), at: 0) }
                    draft = ""
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            } footer: {
                Text("Kept on this watch only.")
            }
            ForEach(session.records.journal) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.text).font(.footnote)
                    Text(e.date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .onDelete { idx in session.updateRecords { $0.journal.remove(atOffsets: idx) } }
        }
        .navigationTitle("Gratitude")
    }
}

/// Travel (qasr and jamʿ) summary by madhhab. For scholar review.
struct TravelGuidanceView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        List {
            Section {
                Text("While travelling, the four-rakʿah prayers (Dhuhr, Asr, Isha) are shortened to two. Fajr and Maghrib are not shortened.")
                    .font(.footnote)
            }
            Section("Your madhhab: \(session.settings.settings.madhhab.title)") {
                Text(guidance).font(.footnote)
            }
            Section {
                Text("Distances are approximate and scholars differ on details such as the length of stay. Ask a scholar you trust about your situation. Draft for scholar review.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Travel")
    }

    private var guidance: String {
        switch session.settings.settings.madhhab {
        case .hanafi:
            return "Shortening is required (wajib) on a journey of about 77–88 km or more, until you intend to stay 15 days or more. Combining two prayers in one time is not permitted, except at ʿArafah and Muzdalifah during Hajj."
        case .shafii, .hanbali:
            return "Shortening is permitted on a journey of about 81–89 km or more; staying four days or more ends travel status. Dhuhr with Asr, and Maghrib with Isha, may be combined in either time."
        case .maliki:
            return "Shortening is a confirmed sunnah on a journey of about 81–89 km or more; intending to stay four days or more ends travel status. Combining is permitted in specific circumstances while travelling."
        }
    }
}
