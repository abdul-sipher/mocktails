import Foundation

/// One prayer on one day. Kept only on this watch, never in privacy mode.
struct PrayerRecord: Codable, Equatable, Identifiable {
    enum Status: String, Codable { case prayed, missed }

    var id: String { "\(day)-\(prayer.rawValue)" }
    let day: String          // yyyy-M-d in the watch's calendar
    let prayer: PrayerName
    var status: Status
    var rakahs: Int?
    var updatedAt: Date
}

struct JournalEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    let text: String
    let date: Date
}

/// Prayer history, qada count and gratitude journal.
struct Records: Codable, Equatable {
    var prayers: [PrayerRecord] = []
    /// Prayers owed and not yet made up.
    var qadaOwed: Int = 0
    var journal: [JournalEntry] = []
    /// "Was this helpful?" answers for calm reminders.
    var calmHelpful = 0
    var calmNotHelpful = 0

    static let key = "records.v1"

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    func record(for prayer: PrayerName, on date: Date, calendar: Calendar = .current) -> PrayerRecord? {
        prayers.first { $0.day == Self.dayKey(date, calendar: calendar) && $0.prayer == prayer }
    }

    /// Set a prayer's status; marking missed adds one qada, un-marking removes it.
    mutating func set(_ status: PrayerRecord.Status?, for prayer: PrayerName, on date: Date,
                      rakahs: Int? = nil, now: Date = Date(), calendar: Calendar = .current) {
        let day = Self.dayKey(date, calendar: calendar)
        let previous = prayers.first { $0.day == day && $0.prayer == prayer }?.status
        prayers.removeAll { $0.day == day && $0.prayer == prayer }
        if let status {
            prayers.append(PrayerRecord(day: day, prayer: prayer, status: status, rakahs: rakahs, updatedAt: now))
        }
        if previous != .missed && status == .missed { qadaOwed += 1 }
        if previous == .missed && status != .missed { qadaOwed = max(0, qadaOwed - 1) }
    }

    mutating func madeUpOne() { qadaOwed = max(0, qadaOwed - 1) }

    /// Days in a row (ending today or yesterday) with all five prayed.
    func fullDayStreak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        var streak = 0
        var day = now
        // Today counts only once complete; otherwise start from yesterday.
        if !allPrayed(on: day, calendar: calendar) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        while allPrayed(on: day, calendar: calendar) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    private func allPrayed(on date: Date, calendar: Calendar) -> Bool {
        PrayerName.allCases.allSatisfy { record(for: $0, on: date, calendar: calendar)?.status == .prayed }
    }

    static func load(from d: UserDefaults = AppGroup.defaults) -> Records {
        guard let data = d.data(forKey: key), let r = try? JSONDecoder().decode(Records.self, from: data) else { return Records() }
        return r
    }

    func save(to d: UserDefaults = AppGroup.defaults) {
        if let data = try? JSONEncoder().encode(self) { d.set(data, forKey: Self.key) }
    }

    /// Everything personal this app stores, for "Delete all my data".
    static let personalKeys = [Records.key, MemorisationPlan.key, CalibrationProfile.key,
                               MosqueLibrary.key, DuaFavourites.key, "wuduSince"]
}
