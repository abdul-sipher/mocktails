import SwiftUI
import Adhan

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @ObservedObject var store: SettingsStore
    @State private var confirmDelete = false

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
                Toggle("Prayer alerts", isOn: $store.settings.prayerAlerts)
                    .onChange(of: store.settings.prayerAlerts) { _, on in
                        if on { Task { await session.prepareAlerts() } }
                    }
                Picker("Heads-up", selection: $store.settings.headsUpMinutes) {
                    ForEach(AlertPlanner.headsUpChoices, id: \.self) { m in
                        Text(m == 0 ? "Off" : "\(m) min before").tag(m)
                    }
                }
                .disabled(!store.settings.prayerAlerts)
                Toggle("Suggest nearest mosque", isOn: $store.settings.mosqueNudge)
                    .disabled(!store.settings.prayerAlerts || store.settings.headsUpMinutes == 0)
                Toggle("Wudu reminder", isOn: $store.settings.wuduReminder)
                    .disabled(!store.settings.prayerAlerts || store.settings.headsUpMinutes == 0)
            } header: {
                Text("Alerts")
            } footer: {
                Text(session.alertsDenied
                     ? "Notifications are off for Sakīnah. Turn them on in the Watch app ▸ Notifications."
                     : "An alert at each prayer time, and an optional heads-up before it.")
            }

            Section {
                Stepper(value: $store.settings.hijriOffset, in: -2...2) {
                    VStack(alignment: .leading) {
                        Text("Hijri date")
                        Text(HijriDate.string(for: Date(), offsetDays: store.settings.hijriOffset))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Calendar")
            } footer: {
                Text("Umm al-Qura calendar. Adjust by a day or two to match your local moon sighting.")
            }

            Section {
                Toggle("Haptics during salah", isOn: $store.settings.rakahHaptics)
                Toggle("Gentle rakah taps", isOn: $store.settings.gentleBuzz)
                    .disabled(!store.settings.rakahHaptics)
                Toggle("Khushu mode", isOn: $store.settings.khushuMode)
                Toggle("Buzz when facing qibla", isOn: $store.settings.qiblaHaptic)
                Picker("Watch on", selection: $store.settings.wrist) {
                    ForEach(Wrist.allCases) { w in Text("\(w.title) wrist").tag(w) }
                }
            } header: {
                Text("Salah")
            } footer: {
                Text("Haptics: N buzzes after rakah N (gentle or strong). Khushu mode shows a dark screen with one dim number during salah; touch and hold to finish. The wrist setting is used by motion counting.")
            }

            Section {
                Toggle("Travelling", isOn: $store.settings.travelling)
                NavigationLink("Travel guidance") { TravelGuidanceView() }
            } header: {
                Text("Travel")
            } footer: {
                Text("When on, Dhuhr, Asr and Isha start at two rakʿāt in the salah tracker.")
            }

            Section {
                Toggle("Privacy mode", isOn: $store.settings.privacyMode)
                Toggle("Mindful minutes in Health", isOn: $store.settings.mindfulMinutes)
                    .onChange(of: store.settings.mindfulMinutes) { _, on in
                        if on { Task { _ = await session.mindful.requestAuthorization() } }
                    }
                    .disabled(store.settings.privacyMode)
                Toggle("Qada reminder", isOn: $store.settings.qadaReminder)
                Button("Delete all my data", role: .destructive) { confirmDelete = true }
            } header: {
                Text("Privacy and records")
            } footer: {
                Text("Everything stays on this watch. Privacy mode keeps no record of salah sessions. Deleting removes history, journal, memorisation, calibration, saved mosques and favourites; settings stay.")
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
        .confirmationDialog("Delete all your Sakīnah data on this watch?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { session.deleteAllData() }
            Button("Cancel", role: .cancel) {}
        }
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
    @State private var confirmDelete = false

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
