import SwiftUI

struct TimetableView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        List {
            if let t = session.timetable {
                Section("Today") {
                    row(PrayerName.fajr.title, t.fajr, id: "fajr")
                    row("Sunrise", t.sunrise, id: "sunrise")
                    row(PrayerName.dhuhr.displayTitle(isFriday: t.isFriday), t.dhuhr, id: "dhuhr")
                    row(PrayerName.asr.title, t.asr, id: "asr")
                    row(PrayerName.maghrib.title, t.maghrib, id: "maghrib")
                    row(PrayerName.isha.title, t.isha, id: "isha",
                        note: "Best before \(t.middleOfNight.formatted(date: .omitted, time: .shortened))")
                }
                Section {
                    ForEach(t.makruhPeriods) { p in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.title)
                            Text("\(p.start.formatted(date: .omitted, time: .shortened)) – \(p.end.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Voluntary prayer disliked")
                } footer: {
                    Text("Approximate minutes. After Asr prayer, voluntary prayer is also disliked until sunset.")
                }
                Section("Night") {
                    row("Last third begins", t.lastThirdOfNight, id: "lastthird")
                }
            } else {
                Text(session.timesUnavailable
                     ? "Times unavailable today at this latitude. Change the high-latitude rule in Settings."
                     : "Awaiting location…")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Timetable")
    }

    private func row(_ title: String, _ date: Date, id: String, note: String? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let note { Text(note).font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer()
            Text(date, style: .time)
                .monospacedDigit()
                .accessibilityIdentifier("time-\(id)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("row-\(id)")
    }
}
