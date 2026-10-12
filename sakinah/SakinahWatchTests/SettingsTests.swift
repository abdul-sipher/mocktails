import XCTest
import Adhan

@MainActor
final class SettingsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "SettingsTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testRoundTripThroughStore() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.settings.method = .egyptian
        store.settings.asr = .hanafi
        store.settings.setOffset(3, for: .asr)
        store.settings.hasChosenMethod = true

        let reloaded = SettingsStore(defaults: defaults).settings
        XCTAssertEqual(reloaded.method, .egyptian)
        XCTAssertEqual(reloaded.asr, .hanafi)
        XCTAssertEqual(reloaded.offset(for: .asr), 3)
        XCTAssertEqual(reloaded.offset(for: .fajr), 0)
        XCTAssertTrue(reloaded.hasChosenMethod)
    }

    func testEmptyBlobDecodesToDefaults() throws {
        let s = try JSONDecoder().decode(PrayerSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(s, PrayerSettings())
        XCTAssertFalse(s.calmReminders, "calm reminders are opt-in")
    }

    func testUnknownAndBadFieldsDoNotResetOthers() throws {
        let json = #"{"method":"karachi","asr":"not-a-school","futureSetting":42,"hasChosenMethod":true}"#
        let s = try JSONDecoder().decode(PrayerSettings.self, from: Data(json.utf8))
        XCTAssertEqual(s.method, .karachi)
        XCTAssertEqual(s.asr, .standard, "bad value falls back to default only for that field")
        XCTAssertTrue(s.hasChosenMethod)
    }

    func testOffsetsClampToRange() {
        var s = PrayerSettings()
        s.setOffset(99, for: .isha)
        XCTAssertEqual(s.offset(for: .isha), 30)
        s.setOffset(0, for: .isha)
        XCTAssertNil(s.offsets["isha"])
    }

    func testSuggestedMethodByRegion() {
        XCTAssertEqual(PrayerSettings.suggestedMethod(regionCode: "AU"), .muslimWorldLeague)
        XCTAssertEqual(PrayerSettings.suggestedMethod(regionCode: "SA"), .ummAlQura)
        XCTAssertEqual(PrayerSettings.suggestedMethod(regionCode: "PK"), .karachi)
        XCTAssertEqual(PrayerSettings.suggestedMethod(regionCode: "us"), .northAmerica)
        XCTAssertEqual(PrayerSettings.suggestedMethod(regionCode: nil), .muslimWorldLeague)
    }

    func testMadhhabSuggestsAsr() {
        XCTAssertEqual(Madhhab.hanafi.suggestedAsr, .hanafi)
        XCTAssertEqual(Madhhab.maliki.suggestedAsr, .standard)
    }
}
