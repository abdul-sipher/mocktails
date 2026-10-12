import SwiftUI
import Adhan

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @ObservedObject var store: SettingsStore

    var body: some View {
        List {
            Section {
                Picker("Method", selection: $store.settings.method) {
                    ForEach(CalculationMethod.selectable) { m in
                        Text(m.title).tag(m)
                    }
                }
                Picker("Asr", selection: $store.settings.asr) {
                    ForEach(AsrSchool.allCases) { a in
                        VStack(alignment: .leading) {
                            Text(a.title)
                            Text(a.detail).font(.caption2).foregroundStyle(.secondary)
                        }
                        .tag(a)
                    }
                }
                if isHighLatitude {
                    Picker("High latitude", selection: $store.settings.highLatitude) {
                        ForEach(HighLatitudeChoice.allCases) { h in
                            Text(h.title).tag(h)
                        }
                    }
                }
                NavigationLink {
                    OffsetsView(store: store)
                } label: {
                    LabeledContent("Adjust minutes", value: offsetsSummary)
                }
            } header: {
                Text("Prayer times")
            } footer: {
                Text("Times recalculate as soon as you change these. Use Adjust minutes to match your mosque's timetable.")
            }

            Section {
                Picker("Madhhab", selection: $store.settings.madhhab) {
                    ForEach(Madhhab.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
            } header: {
                Text("Madhhab")
            } footer: {
                Text("Your school of fiqh. It does not change the calculation method; Asr is set above.")
            }

            Section {
                Toggle("Calm reminders", isOn: $store.settings.calmReminders)
            } header: {
                Text("Wellbeing")
            } footer: {
                Text("Off by default. When on, Sakīnah reads heart rate from Health and may invite you to pause for dhikr. A raised heart rate can mean many things; this is not a diagnosis.")
            }
        }
        .navigationTitle("Settings")
    }

    /// The rule only matters far from the equator (Adhan's own threshold is 48°).
    private var isHighLatitude: Bool {
        guard let lat = session.lastCoordinate?.latitude else { return false }
        return abs(lat) > 48 || store.settings.highLatitude != .auto
    }

    private var offsetsSummary: String {
        let n = PrayerName.allCases.filter { store.settings.offset(for: $0) != 0 }.count
        return n == 0 ? "None" : "\(n) set"
    }
}

struct OffsetsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        List {
            ForEach(PrayerName.allCases) { prayer in
                Stepper(value: binding(for: prayer), in: PrayerSettings.offsetRange) {
                    VStack(alignment: .leading) {
                        Text(prayer.title)
                        Text(label(for: store.settings.offset(for: prayer)))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Adjust minutes")
    }

    private func binding(for prayer: PrayerName) -> Binding<Int> {
        Binding(
            get: { store.settings.offset(for: prayer) },
            set: { store.settings.setOffset($0, for: prayer) }
        )
    }

    private func label(for minutes: Int) -> String {
        minutes == 0 ? "As calculated" : String(format: "%+d min", minutes)
    }
}
