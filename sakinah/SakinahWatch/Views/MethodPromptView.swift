import SwiftUI
import Adhan

/// First launch: confirm how prayer times are calculated. Cannot be
/// skipped; the suggested method is preselected so it is one tap.
struct MethodPromptView: View {
    @ObservedObject var store: SettingsStore
    let onDone: () -> Void

    @State private var method = PrayerSettings.suggestedMethod(regionCode: Locale.current.region?.identifier)
    @State private var madhhab: Madhhab = .shafii
    @State private var asr: AsrSchool = .standard
    @State private var wrist: Wrist = .left

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose how your prayer times are calculated. You can change this any time in Settings.")
                        .font(.footnote)
                }
                Section {
                    Picker("Method", selection: $method) {
                        ForEach(CalculationMethod.selectable) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    Picker("Madhhab", selection: $madhhab) {
                        ForEach(Madhhab.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    Picker("Asr", selection: $asr) {
                        ForEach(AsrSchool.allCases) { a in
                            Text(a.title).tag(a)
                        }
                    }
                } footer: {
                    Text("Method suggested for your region. Hanafi Asr is later than the standard time.")
                }
                Section {
                    Picker("Watch worn on", selection: $wrist) {
                        ForEach(Wrist.allCases) { w in Text("\(w.title) wrist").tag(w) }
                    }
                } footer: {
                    Text("Next, Sakīnah asks to send prayer alerts. Location is used only on this watch, for prayer times and nearby mosques.")
                }
                Button("Continue") {
                    store.settings.method = method
                    store.settings.madhhab = madhhab
                    store.settings.asr = asr
                    store.settings.wrist = wrist
                    store.settings.hasChosenMethod = true
                    onDone()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Prayer times")
            // Replace the sheet's close button: the choice is required (one tap).
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Color.clear.frame(width: 1, height: 1) }
            }
        }
        .onChange(of: madhhab) { _, new in asr = new.suggestedAsr }
        .interactiveDismissDisabled()
    }
}
