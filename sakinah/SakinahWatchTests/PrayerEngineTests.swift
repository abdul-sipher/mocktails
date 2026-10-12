import XCTest
import CoreLocation
import Adhan

/// Engine checks. Fixtures are Adhan's published reference timetables
/// (sources listed inside each JSON, licence in Fixtures/ADHAN-LICENSE.txt);
/// they prove our settings → parameters mapping and time-zone handling.
final class PrayerEngineTests: XCTestCase {

    // MARK: - Fixtures

    func testMakkahUmmAlQura() throws { try checkFixture("Makkah-UmmAlQura") }
    func testLondonMoonsightingHanafi() throws { try checkFixture("London-MoonsightingCommittee") }
    func testTehranHalfHourZone() throws { try checkFixture("Tehran-Tehran") }
    func testDubai() throws { try checkFixture("Dubai-Gulf") }
    func testSingaporeWholeYear() throws { try checkFixture("Singapore-Singapore") }

    private func checkFixture(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"),
                                "missing fixture \(name)", file: file, line: line)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let params = try XCTUnwrap(json["params"] as? [String: Any])
        let variance = (json["variance"] as? Double) ?? 0
        let tz = try XCTUnwrap(TimeZone(identifier: params["timezone"] as! String))
        let coord = CLLocationCoordinate2D(latitude: params["latitude"] as! Double,
                                           longitude: params["longitude"] as! Double)
        var settings = PrayerSettings()
        settings.method = try XCTUnwrap(Self.methods[params["method"] as! String])
        settings.asr = (params["madhab"] as! String) == "Hanafi" ? .hanafi : .standard
        settings.highLatitude = try XCTUnwrap(Self.highLat[params["highLatitudeRule"] as! String])

        let dayParser = DateFormatter()
        dayParser.locale = Locale(identifier: "en_US_POSIX")
        dayParser.timeZone = tz
        dayParser.dateFormat = "yyyy-MM-dd HH:mm"
        let timeParser = DateFormatter()
        timeParser.locale = Locale(identifier: "en_US_POSIX")
        timeParser.timeZone = tz
        timeParser.dateFormat = "yyyy-MM-dd h:mm a"

        let times = try XCTUnwrap(json["times"] as? [[String: String]])
        XCTAssertFalse(times.isEmpty)
        for entry in times {
            let dayString = entry["date"]!
            let noon = try XCTUnwrap(dayParser.date(from: "\(dayString) 12:00"))
            let t = try XCTUnwrap(PrayerEngine.timetable(on: noon, at: coord, timeZone: tz, settings: settings),
                                  "\(name) \(dayString): no timetable", file: file, line: line)
            let actual: [(String, Date)] = [("fajr", t.fajr), ("sunrise", t.sunrise), ("dhuhr", t.dhuhr),
                                            ("asr", t.asr), ("maghrib", t.maghrib), ("isha", t.isha)]
            for (key, date) in actual {
                let expected = try XCTUnwrap(timeParser.date(from: "\(dayString) \(entry[key]!)"))
                let diff = abs(date.timeIntervalSince(expected)) / 60
                XCTAssertLessThanOrEqual(diff, variance,
                    "\(name) \(dayString) \(key): off by \(diff) min", file: file, line: line)
            }
        }
    }

    private static let methods: [String: CalculationMethod] = [
        "UmmAlQura": .ummAlQura, "MoonsightingCommittee": .moonsightingCommittee,
        "Tehran": .tehran, "Dubai": .dubai, "Singapore": .singapore
    ]
    private static let highLat: [String: HighLatitudeChoice] = [
        "MiddleOfTheNight": .middleOfTheNight, "SeventhOfTheNight": .seventhOfTheNight,
        "TwilightAngle": .twilightAngle
    ]

    // MARK: - Places without a published fixture

    private let sydney = CLLocationCoordinate2D(latitude: -33.9205, longitude: 151.0756)
    private let sydneyTZ = TimeZone(identifier: "Australia/Sydney")!

    private func date(_ s: String, _ tz: TimeZone) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }

    private func hourMinute(_ d: Date, _ tz: TimeZone) -> (Int, Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: d)
        return (c.hour!, c.minute!)
    }

    func testSydneyDaylightSavingShift() throws {
        // Clocks go forward on Sun 4 Oct 2026.
        let before = try XCTUnwrap(PrayerEngine.timetable(on: date("2026-10-03 12:00", sydneyTZ), at: sydney, timeZone: sydneyTZ, settings: PrayerSettings()))
        let after = try XCTUnwrap(PrayerEngine.timetable(on: date("2026-10-04 12:00", sydneyTZ), at: sydney, timeZone: sydneyTZ, settings: PrayerSettings()))
        XCTAssertEqual(hourMinute(before.dhuhr, sydneyTZ).0, 11)
        XCTAssertEqual(hourMinute(after.dhuhr, sydneyTZ).0, 12)
    }

    func testAdelaideHalfHourZone() throws {
        let tz = TimeZone(identifier: "Australia/Adelaide")!
        let adelaide = CLLocationCoordinate2D(latitude: -34.9285, longitude: 138.6007)
        let t = try XCTUnwrap(PrayerEngine.timetable(on: date("2026-10-12 12:00", tz), at: adelaide, timeZone: tz, settings: PrayerSettings()))
        let (h, m) = hourMinute(t.dhuhr, tz)
        let minutes = h * 60 + m
        // Solar noon is about 12:57 ACDT; truncating +10:30 to +10 would give ~12:27.
        XCTAssertTrue((12 * 60 + 50)...(13 * 60 + 10) ~= minutes, "Adelaide Dhuhr \(h):\(m)")
    }

    func testOsloMidsummerUsesHighLatitudeRule() throws {
        let tz = TimeZone(identifier: "Europe/Oslo")!
        let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
        let t = try XCTUnwrap(PrayerEngine.timetable(on: date("2026-06-21 12:00", tz), at: oslo, timeZone: tz, settings: PrayerSettings()))
        XCTAssertLessThan(t.fajr, t.sunrise)
        XCTAssertLessThan(t.maghrib, t.isha)
        XCTAssertLessThan(t.isha, t.nextFajr)
    }

    // MARK: - Timetable behaviour

    private func sydneyDay(_ day: String = "2026-10-12", settings: PrayerSettings = PrayerSettings()) throws -> DayTimetable {
        try XCTUnwrap(PrayerEngine.timetable(on: date("\(day) 12:00", sydneyTZ), at: sydney, timeZone: sydneyTZ, settings: settings))
    }

    func testOrderingAndNextPrayerRollsOverAfterIsha() throws {
        let t = try sydneyDay()
        XCTAssertEqual([t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha],
                       [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha].sorted())
        XCTAssertEqual(t.next(after: t.fajr.addingTimeInterval(-60)).name, .fajr)
        XCTAssertEqual(t.next(after: t.dhuhr).name, .asr)
        let late = t.next(after: t.isha.addingTimeInterval(60))
        XCTAssertEqual(late.name, .fajr)
        XCTAssertEqual(late.date, t.nextFajr)
        XCTAssertGreaterThan(t.nextFajr, t.isha)
    }

    func testNoWindowBetweenSunriseAndDhuhr() throws {
        let t = try sydneyDay()
        XCTAssertNil(t.window(at: t.sunrise.addingTimeInterval(30 * 60)))
        XCTAssertEqual(t.window(at: t.fajr.addingTimeInterval(60))?.prayer, .fajr)
        XCTAssertEqual(t.window(at: t.fajr.addingTimeInterval(60))?.end, t.sunrise)
    }

    func testIshaWindowEndsAtNextFajrWithPreferredMidnight() throws {
        let t = try sydneyDay()
        let w = try XCTUnwrap(t.window(at: t.isha.addingTimeInterval(60)))
        XCTAssertEqual(w.prayer, .isha)
        XCTAssertEqual(w.end, t.nextFajr)
        XCTAssertEqual(w.preferredEnd, t.middleOfNight)
    }

    func testCurrentWindowBeforeFajrIsLastNightsIsha() throws {
        let t = try sydneyDay()
        let w = PrayerEngine.currentWindow(at: t.fajr.addingTimeInterval(-30 * 60), at: sydney, timeZone: sydneyTZ, settings: PrayerSettings())
        XCTAssertEqual(w?.prayer, .isha)
    }

    func testOffsetMovesOnlyThatPrayer() throws {
        let base = try sydneyDay()
        var s = PrayerSettings()
        s.setOffset(5, for: .asr)
        let shifted = try sydneyDay(settings: s)
        XCTAssertEqual(shifted.asr.timeIntervalSince(base.asr), 5 * 60, accuracy: 1)
        XCTAssertEqual(shifted.dhuhr, base.dhuhr)
        XCTAssertEqual(shifted.maghrib, base.maghrib)
    }

    func testMethodAndAsrChangeTimes() throws {
        let mwl = try sydneyDay()
        var s = PrayerSettings()
        s.method = .egyptian
        XCTAssertLessThan(try sydneyDay(settings: s).fajr, mwl.fajr, "Egyptian 19.5° Fajr is earlier than MWL 18°")
        var h = PrayerSettings()
        h.asr = .hanafi
        XCTAssertGreaterThan(try sydneyDay(settings: h).asr, mwl.asr)
    }

    func testFridayFlag() throws {
        XCTAssertTrue(try sydneyDay("2026-10-16").isFriday)
        XCTAssertFalse(try sydneyDay("2026-10-12").isFriday)
        XCTAssertEqual(PrayerName.dhuhr.displayTitle(isFriday: true), "Jumuʿah")
        XCTAssertEqual(PrayerName.asr.displayTitle(isFriday: true), "Asr")
    }
}
