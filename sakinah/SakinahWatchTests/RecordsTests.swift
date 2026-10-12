import XCTest

final class RecordsTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return c
    }()
    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    func testMissedAddsQadaAndUnmarkingRemovesIt() {
        var r = Records()
        r.set(.missed, for: .fajr, on: day, calendar: cal)
        XCTAssertEqual(r.qadaOwed, 1)
        r.set(.missed, for: .fajr, on: day, calendar: cal)
        XCTAssertEqual(r.qadaOwed, 1, "same prayer marked twice counts once")
        r.set(.prayed, for: .fajr, on: day, calendar: cal)
        XCTAssertEqual(r.qadaOwed, 0)
        XCTAssertEqual(r.record(for: .fajr, on: day, calendar: cal)?.status, .prayed)
        r.set(nil, for: .fajr, on: day, calendar: cal)
        XCTAssertNil(r.record(for: .fajr, on: day, calendar: cal))
    }

    func testMadeUpNeverGoesNegative() {
        var r = Records()
        r.madeUpOne()
        XCTAssertEqual(r.qadaOwed, 0)
    }

    func testFullDayStreak() {
        var r = Records()
        for offset in 1...2 {
            let d = cal.date(byAdding: .day, value: -offset, to: day)!
            for p in PrayerName.allCases { r.set(.prayed, for: p, on: d, calendar: cal) }
        }
        XCTAssertEqual(r.fullDayStreak(now: day, calendar: cal), 2, "today incomplete; yesterday and the day before")
        for p in PrayerName.allCases { r.set(.prayed, for: p, on: day, calendar: cal) }
        XCTAssertEqual(r.fullDayStreak(now: day, calendar: cal), 3)
    }

    func testRoundTripAndDeleteKeys() {
        let name = "Rec-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        var r = Records()
        r.journal.append(JournalEntry(text: "Rain after a dry week", date: day))
        r.set(.missed, for: .isha, on: day, calendar: cal)
        r.save(to: d)
        XCTAssertEqual(Records.load(from: d), r)
        for k in Records.personalKeys { d.removeObject(forKey: k) }
        XCTAssertEqual(Records.load(from: d), Records())
    }
}
