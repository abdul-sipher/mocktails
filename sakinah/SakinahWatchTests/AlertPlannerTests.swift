import XCTest
import CoreLocation

final class AlertPlannerTests: XCTestCase {
    private let sydney = CLLocationCoordinate2D(latitude: -33.9205, longitude: 151.0756)
    private let tz = TimeZone(identifier: "Australia/Sydney")!

    private func days(from start: Date, count: Int, settings: PrayerSettings) -> [DayTimetable] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return (0..<count).compactMap {
            PrayerEngine.timetable(on: cal.date(byAdding: .day, value: $0, to: start)!, at: sydney, timeZone: tz, settings: settings)
        }
    }

    private func noon(_ s: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: "\(s) 12:00")!
    }

    func testOnlyFutureAlertsWithHeadsUp() {
        var s = PrayerSettings()
        s.headsUpMinutes = 10
        let now = noon("2026-10-12")  // after Fajr and Dhuhr? Dhuhr ~12:43, so Fajr is past
        let t = days(from: now, count: 1, settings: s)
        let plan = AlertPlanner.plan(timetables: t, settings: s, now: now, mosque: nil)
        XCTAssertFalse(plan.contains { $0.id.contains("-fajr") }, "Fajr already passed")
        XCTAssertTrue(plan.allSatisfy { $0.date > now })
        let dhuhr = plan.first { $0.id.hasPrefix("prayer-") && $0.id.hasSuffix("-dhuhr") }!
        let headsUp = plan.first { $0.id.hasPrefix("headsup-") && $0.id.hasSuffix("-dhuhr") }!
        XCTAssertEqual(dhuhr.date.timeIntervalSince(headsUp.date), 600, accuracy: 1)
        XCTAssertEqual(headsUp.title, "Dhuhr in 10 min")
        XCTAssertEqual(plan, plan.sorted { $0.date < $1.date })
    }

    func testMosqueNamedInHeadsUpOnlyWhenEnabled() {
        var s = PrayerSettings()
        s.headsUpMinutes = 10
        let now = noon("2026-10-12")
        let t = days(from: now, count: 1, settings: s)
        let withMosque = AlertPlanner.plan(timetables: t, settings: s, now: now, mosque: ("Lakemba Musallah", 151))
        XCTAssertTrue(withMosque.contains { $0.body.hasPrefix("Pray at Lakemba Musallah (151 m)?") })
        s.mosqueNudge = false
        let without = AlertPlanner.plan(timetables: t, settings: s, now: now, mosque: ("Lakemba Musallah", 151))
        XCTAssertFalse(without.contains { $0.body.contains("Lakemba") })
    }

    func testAlertsOffMeansNothingAndHeadsUpZeroMeansNoHeadsUp() {
        var s = PrayerSettings()
        let now = noon("2026-10-12")
        let t = days(from: now, count: 2, settings: s)
        s.headsUpMinutes = 0
        XCTAssertTrue(AlertPlanner.plan(timetables: t, settings: s, now: now, mosque: nil).allSatisfy { $0.id.hasPrefix("prayer-") })
        s.prayerAlerts = false
        XCTAssertTrue(AlertPlanner.plan(timetables: t, settings: s, now: now, mosque: nil).isEmpty)
    }

    func testStableIdsAndLimit() {
        var s = PrayerSettings()
        s.headsUpMinutes = 15
        let now = noon("2026-10-12")
        let t = days(from: now, count: 10, settings: s)
        let a = AlertPlanner.plan(timetables: t, settings: s, now: now, mosque: nil)
        let b = AlertPlanner.plan(timetables: t, settings: s, now: now, mosque: nil)
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        XCTAssertLessThanOrEqual(a.count, AlertPlanner.limit)
        XCTAssertEqual(Set(a.map(\.id)).count, a.count)
    }

    func testWuduReminderOnlyWhenNotMarked() {
        var s = PrayerSettings()
        s.headsUpMinutes = 10
        let now = noon("2026-10-12")
        let t = days(from: now, count: 1, settings: s)
        let headsUps = { (has: Bool) in
            AlertPlanner.plan(timetables: t, settings: s, now: now, mosque: nil, hasWudu: has).filter { $0.id.hasPrefix("headsup-") }
        }
        XCTAssertTrue(headsUps(false).allSatisfy { $0.body.hasSuffix("Make wudu before you leave.") })
        XCTAssertTrue(headsUps(true).allSatisfy { !$0.body.contains("wudu") })
        s.wuduReminder = false
        XCTAssertTrue(headsUps(false).allSatisfy { !$0.body.contains("wudu") })
    }

    func testFridayAlertSaysJumuah() {
        let s = PrayerSettings()
        let friday = noon("2026-10-16").addingTimeInterval(-6 * 3600)  // 6 am Friday
        let t = days(from: friday, count: 1, settings: s)
        let plan = AlertPlanner.plan(timetables: t, settings: s, now: friday, mosque: nil)
        XCTAssertTrue(plan.contains { $0.title == "Jumuʿah" })
    }
}
