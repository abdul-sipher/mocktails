import Foundation

/// Surahs offered for memorisation: Al-Fatihah and Juz ʿAmma, with ayah
/// counts (Hafs ʿan ʿAsim numbering).
struct Surah: Identifiable, Hashable, Codable {
    let number: Int
    let name: String
    let ayat: Int
    var id: Int { number }

    static let memorisable: [Surah] = [
        .init(number: 1, name: "Al-Fatihah", ayat: 7),
        .init(number: 78, name: "An-Naba", ayat: 40), .init(number: 79, name: "An-Naziʿat", ayat: 46),
        .init(number: 80, name: "ʿAbasa", ayat: 42), .init(number: 81, name: "At-Takwir", ayat: 29),
        .init(number: 82, name: "Al-Infitar", ayat: 19), .init(number: 83, name: "Al-Mutaffifin", ayat: 36),
        .init(number: 84, name: "Al-Inshiqaq", ayat: 25), .init(number: 85, name: "Al-Buruj", ayat: 22),
        .init(number: 86, name: "At-Tariq", ayat: 17), .init(number: 87, name: "Al-Aʿla", ayat: 19),
        .init(number: 88, name: "Al-Ghashiyah", ayat: 26), .init(number: 89, name: "Al-Fajr", ayat: 30),
        .init(number: 90, name: "Al-Balad", ayat: 20), .init(number: 91, name: "Ash-Shams", ayat: 15),
        .init(number: 92, name: "Al-Layl", ayat: 21), .init(number: 93, name: "Ad-Duha", ayat: 11),
        .init(number: 94, name: "Ash-Sharh", ayat: 8), .init(number: 95, name: "At-Tin", ayat: 8),
        .init(number: 96, name: "Al-ʿAlaq", ayat: 19), .init(number: 97, name: "Al-Qadr", ayat: 5),
        .init(number: 98, name: "Al-Bayyinah", ayat: 8), .init(number: 99, name: "Az-Zalzalah", ayat: 8),
        .init(number: 100, name: "Al-ʿAdiyat", ayat: 11), .init(number: 101, name: "Al-Qariʿah", ayat: 11),
        .init(number: 102, name: "At-Takathur", ayat: 8), .init(number: 103, name: "Al-ʿAsr", ayat: 3),
        .init(number: 104, name: "Al-Humazah", ayat: 9), .init(number: 105, name: "Al-Fil", ayat: 5),
        .init(number: 106, name: "Quraysh", ayat: 4), .init(number: 107, name: "Al-Maʿun", ayat: 7),
        .init(number: 108, name: "Al-Kawthar", ayat: 3), .init(number: 109, name: "Al-Kafirun", ayat: 6),
        .init(number: 110, name: "An-Nasr", ayat: 3), .init(number: 111, name: "Al-Masad", ayat: 5),
        .init(number: 112, name: "Al-Ikhlas", ayat: 4), .init(number: 113, name: "Al-Falaq", ayat: 5),
        .init(number: 114, name: "An-Nas", ayat: 6)
    ]
}

/// A small daily memorisation goal plus a revision queue.
struct MemorisationPlan: Codable, Equatable {
    var surahNumber: Int = 112
    var dailyTarget: Int = 3
    var memorisedAyat: Int = 0
    var lastLoggedDay: String?
    var streak: Int = 0
    /// Finished surahs and when each was last revised.
    var revised: [Int: Date] = [:]

    static let key = "memorisation.v1"

    var surah: Surah { Surah.memorisable.first { $0.number == surahNumber } ?? Surah.memorisable[0] }
    var isComplete: Bool { memorisedAyat >= surah.ayat }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    func loggedToday(_ now: Date = Date(), calendar: Calendar = .current) -> Bool {
        lastLoggedDay == Self.dayKey(now, calendar: calendar)
    }

    /// Mark today's target done. Streak continues from yesterday only.
    mutating func logToday(_ now: Date = Date(), calendar: Calendar = .current) {
        guard !loggedToday(now, calendar: calendar) else { return }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now).map { Self.dayKey($0, calendar: calendar) }
        streak = lastLoggedDay == yesterday ? streak + 1 : 1
        lastLoggedDay = Self.dayKey(now, calendar: calendar)
        memorisedAyat = min(surah.ayat, memorisedAyat + dailyTarget)
        if isComplete { revised[surahNumber] = now }
    }

    mutating func choose(_ surah: Surah) {
        surahNumber = surah.number
        memorisedAyat = 0
    }

    /// The finished surah revised longest ago.
    var nextRevision: Surah? {
        revised.sorted { $0.value < $1.value }.first.flatMap { entry in Surah.memorisable.first { $0.number == entry.key } }
    }

    mutating func markRevised(_ surah: Surah, at now: Date = Date()) { revised[surah.number] = now }

    static func load(from d: UserDefaults = AppGroup.defaults) -> MemorisationPlan {
        guard let data = d.data(forKey: key), let p = try? JSONDecoder().decode(MemorisationPlan.self, from: data) else { return MemorisationPlan() }
        return p
    }

    func save(to d: UserDefaults = AppGroup.defaults) {
        if let data = try? JSONEncoder().encode(self) { d.set(data, forKey: Self.key) }
    }
}

/// Hijri date from the Umm al-Qura calendar, with a user offset because
/// local moon sighting can differ by a day or two.
enum HijriDate {
    static func calendar() -> Calendar {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.locale = Locale(identifier: "en")
        return c
    }

    static func components(for date: Date, offsetDays: Int) -> DateComponents {
        let cal = calendar()
        let shifted = cal.date(byAdding: .day, value: offsetDays, to: date) ?? date
        return cal.dateComponents([.year, .month, .day], from: shifted)
    }

    static func isRamadan(_ date: Date, offsetDays: Int) -> Bool {
        components(for: date, offsetDays: offsetDays).month == 9
    }

    static func string(for date: Date, offsetDays: Int) -> String {
        let cal = calendar()
        let shifted = cal.date(byAdding: .day, value: offsetDays, to: date) ?? date
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en")
        f.dateFormat = "d MMMM y"
        return f.string(from: shifted) + " AH"
    }
}
