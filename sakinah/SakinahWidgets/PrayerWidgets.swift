import WidgetKit
import SwiftUI

@main
struct SakinahWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
        NearestMosqueWidget()
    }
}

// MARK: - Next prayer

struct PrayerEntry: TimelineEntry {
    enum State { case ready, noLocation, unavailable }

    let date: Date
    let state: State
    let next: PrayerTime?
    let isFriday: Bool
    let window: PrayerWindow?
    let relevance: TimelineEntryRelevance?

    var nextTitle: String {
        guard let next else { return "" }
        return next.name.displayTitle(isFriday: isFriday && Calendar.current.isDate(next.date, inSameDayAs: date))
    }
}

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: .now, state: .ready,
                    next: PrayerTime(name: .asr, date: .now.addingTimeInterval(45 * 60)),
                    isFriday: false, window: nil, relevance: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    /// One entry now and one at every prayer boundary over the next day,
    /// so the next prayer flips exactly when a prayer begins.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = Date()
        var dates = [now]
        if let snap = SharedSnapshot.load() {
            let settings = AppGroup.loadSettings()
            let tz = TimeZone.current
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            for offset in 0...1 {
                guard let day = cal.date(byAdding: .day, value: offset, to: now),
                      let t = PrayerEngine.timetable(on: day, at: snap.coordinate, timeZone: tz, settings: settings)
                else { continue }
                let boundaries = t.prayers.map(\.date) + [t.sunrise, t.middleOfNight]
                    + t.prayers.map { $0.date.addingTimeInterval(-30 * 60) }
                dates += boundaries.filter { $0 > now && $0 < now.addingTimeInterval(26 * 3600) }
            }
        }
        let entries = Array(Set(dates)).sorted().map(entry(at:))
        completion(Timeline(entries: entries, policy: .after(entries.last?.date.addingTimeInterval(60) ?? now.addingTimeInterval(3600))))
    }

    private func entry(at date: Date) -> PrayerEntry {
        guard let snap = SharedSnapshot.load() else {
            return PrayerEntry(date: date, state: .noLocation, next: nil, isFriday: false, window: nil, relevance: nil)
        }
        let settings = AppGroup.loadSettings()
        let tz = TimeZone.current
        guard let t = PrayerEngine.timetable(on: date, at: snap.coordinate, timeZone: tz, settings: settings) else {
            return PrayerEntry(date: date, state: .unavailable, next: nil, isFriday: false, window: nil, relevance: nil)
        }
        let next = t.next(after: date)
        let window = PrayerEngine.currentWindow(at: date, at: snap.coordinate, timeZone: tz, settings: settings)
        // Smart Stack: rise to the top in the half hour before a prayer.
        let minutesToNext = next.date.timeIntervalSince(date) / 60
        let relevance = TimelineEntryRelevance(score: minutesToNext <= 30 ? 1 : 0.2)
        return PrayerEntry(date: date, state: .ready, next: next, isFriday: t.isFriday, window: window, relevance: relevance)
    }
}

struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPrayer", provider: PrayerProvider()) { entry in
            NextPrayerView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Next prayer")
        .description("The next prayer and a countdown.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}

struct NextPrayerView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        switch entry.state {
        case .noLocation: message("Open Sakīnah", short: "Open")
        case .unavailable: message("Times unavailable", short: "—")
        case .ready: ready
        }
    }

    @ViewBuilder private var ready: some View {
        if let next = entry.next {
            switch family {
            case .accessoryInline:
                Text("\(entry.nextTitle) ") + Text(next.date, style: .time)
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: "moon.stars.fill").font(.caption2)
                    Text(entry.nextTitle).font(.system(size: 11, weight: .semibold)).minimumScaleFactor(0.6)
                    Text(next.date, format: .dateTime.hour().minute()).font(.system(size: 11)).minimumScaleFactor(0.6)
                }
                .widgetAccentable()
            case .accessoryCorner:
                Text(next.date, format: .dateTime.hour().minute())
                    .widgetCurvesContent()
                    .widgetLabel { Text(entry.nextTitle) }
            default:
                VStack(alignment: .leading, spacing: 1) {
                    HStack {
                        Text(entry.nextTitle).font(.headline).widgetAccentable()
                        Spacer()
                        Text(next.date, style: .time).font(.headline.monospacedDigit())
                    }
                    Text(next.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                    if let w = entry.window {
                        Text("\(w.prayer.title) time now").font(.caption2).foregroundStyle(.green)
                    }
                }
            }
        }
    }

    @ViewBuilder private func message(_ long: String, short: String) -> some View {
        switch family {
        case .accessoryCircular, .accessoryCorner: Text(short)
        default: Text(long)
        }
    }
}

// MARK: - Nearest mosque

struct MosqueEntry: TimelineEntry {
    let date: Date
    let name: String?
    let distanceMeters: Double?
}

struct MosqueProvider: TimelineProvider {
    func placeholder(in context: Context) -> MosqueEntry {
        MosqueEntry(date: .now, name: "Nearest mosque", distanceMeters: 240)
    }

    func getSnapshot(in context: Context, completion: @escaping (MosqueEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    /// The app reloads this widget when it finds a new nearest mosque.
    func getTimeline(in context: Context, completion: @escaping (Timeline<MosqueEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .never))
    }

    private func current() -> MosqueEntry {
        let snap = SharedSnapshot.load()
        return MosqueEntry(date: .now, name: snap?.mosqueName, distanceMeters: snap?.mosqueDistanceMeters)
    }
}

struct NearestMosqueWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NearestMosque", provider: MosqueProvider()) { entry in
            MosqueWidgetView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Nearest mosque")
        .description("The closest mosque the app has found.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

struct MosqueWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MosqueEntry

    var body: some View {
        if let name = entry.name, let d = entry.distanceMeters {
            if family == .accessoryInline {
                Text("\(name) · \(Int(d)) m")
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Label("Nearest mosque", systemImage: "building.columns.fill")
                        .font(.caption2).foregroundStyle(.secondary).widgetAccentable()
                    Text(name).font(.headline).lineLimit(2)
                    Text("\(Int(d)) m away").font(.caption2)
                }
            }
        } else {
            Text(family == .accessoryInline ? "No mosque found yet" : "No mosque found yet. Open Sakīnah nearby.")
        }
    }
}
