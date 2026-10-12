import XCTest

/// Guards the bundled du'a and adhkar content and the memorisation data.
final class ContentTests: XCTestCase {
    private let library = DuaLibrary.load(bundle: Bundle(for: ContentTests.self))

    func testEveryEntryIsComplete() {
        XCTAssertFalse(library.duas.isEmpty)
        let arabicLetters = CharacterSet(charactersIn: "\u{0621}"..."\u{064A}")
        for d in library.duas + library.adhkar {
            XCTAssertFalse(d.title.isEmpty, d.id)
            XCTAssertFalse(d.transliteration.isEmpty, d.id)
            XCTAssertFalse(d.meaning.isEmpty, d.id)
            XCTAssertFalse(d.reference.isEmpty, "\(d.id) needs a source")
            XCTAssertNotNil(d.arabic.unicodeScalars.first { arabicLetters.contains($0) }, "\(d.id) Arabic text")
        }
    }

    func testIdsUnique() {
        let ids = (library.duas + library.adhkar).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testAllTenCategoriesHaveEntries() {
        for c in DuaCategory.allCases {
            XCTAssertFalse(library.duas(in: c).isEmpty, "category \(c.rawValue)")
        }
        XCTAssertTrue(library.duas.allSatisfy { DuaCategory(rawValue: $0.category ?? "") != nil })
    }

    func testAfterSalahTasbihIs33Each() {
        let after = library.adhkar(in: .afterSalah)
        XCTAssertEqual(after.filter { $0.count == 33 }.count, 3)
        XCTAssertTrue(library.adhkar.allSatisfy { ($0.count ?? 0) > 0 && AdhkarSet(rawValue: $0.set ?? "") != nil })
    }

    func testJuzAmmaAyahCount() {
        let juzAmma = Surah.memorisable.filter { $0.number >= 78 }
        XCTAssertEqual(juzAmma.count, 37)
        XCTAssertEqual(juzAmma.map(\.ayat).reduce(0, +), 564)
    }

    func testMemorisationStreakAndProgress() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        var plan = MemorisationPlan()
        plan.choose(Surah.memorisable.first { $0.number == 103 }!)   // Al-ʿAsr, 3 ayat
        plan.dailyTarget = 2
        let day1 = Date(timeIntervalSince1970: 1_800_000_000)
        plan.logToday(day1, calendar: cal)
        plan.logToday(day1, calendar: cal)   // once per day
        XCTAssertEqual(plan.memorisedAyat, 2)
        XCTAssertEqual(plan.streak, 1)
        plan.logToday(day1.addingTimeInterval(86_400), calendar: cal)
        XCTAssertEqual(plan.memorisedAyat, 3, "capped at surah length")
        XCTAssertEqual(plan.streak, 2)
        XCTAssertTrue(plan.isComplete)
        XCTAssertEqual(plan.nextRevision?.number, 103)
        plan.logToday(day1.addingTimeInterval(4 * 86_400), calendar: cal)
        XCTAssertEqual(plan.streak, 1, "a missed day restarts the streak")
    }

    func testRamadan1448() {
        // Umm al-Qura: Ramadan 1448 runs from about 8 Feb to 9 Mar 2027.
        let f = ISO8601DateFormatter()
        XCTAssertTrue(HijriDate.isRamadan(f.date(from: "2027-02-20T12:00:00Z")!, offsetDays: 0))
        XCTAssertFalse(HijriDate.isRamadan(f.date(from: "2026-10-12T12:00:00Z")!, offsetDays: 0))
        XCTAssertTrue(HijriDate.string(for: f.date(from: "2027-02-20T12:00:00Z")!, offsetDays: 0).hasSuffix("1448 AH"))
    }
}
