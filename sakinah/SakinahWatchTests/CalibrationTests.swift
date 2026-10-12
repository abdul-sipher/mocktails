import XCTest

final class CalibrationTests: XCTestCase {
    private let profile = CalibrationProfile(points: [
        .qiyam: .init(gx: 0, gy: -0.8, gz: 0.1),
        .ruku: .init(gx: 0, gy: -0.9, gz: -0.3),
        .sujood: .init(gx: 0, gy: 0, gz: -0.95),
        .jalsa: .init(gx: 0, gy: 0.1, gz: 0.8)
    ], recordedAt: Date())

    func testNearestPostureWins() {
        XCTAssertEqual(profile.classify(.init(gx: 0.05, gy: 0.02, gz: -0.9))?.posture, .sujood)
        XCTAssertEqual(profile.classify(.init(gx: 0, gy: 0.05, gz: 0.85))?.posture, .jalsa)
    }

    func testFarFromEverythingIsUnsure() {
        XCTAssertNil(profile.classify(.init(gx: 1, gy: 0, gz: 0)))
    }

    func testAmbiguousSampleHasLowConfidence() {
        // Halfway between qiyam and ruku.
        let mid = profile.classify(.init(gx: 0, gy: -0.85, gz: -0.1))!
        let clear = profile.classify(.init(gx: 0, gy: 0, gz: -0.95))!
        XCTAssertLessThan(mid.confidence, clear.confidence)
    }

    func testMeanAndRoundTrip() throws {
        let m = CalibrationProfile.Point.mean([.init(gx: 0, gy: 1, gz: 0), .init(gx: 0, gy: 0, gz: 1)])!
        XCTAssertEqual(m.gy, 0.5, accuracy: 1e-9)
        let name = "Cal-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        profile.save(to: d)
        XCTAssertEqual(CalibrationProfile.load(from: d), profile)
        CalibrationProfile.delete(from: d)
        XCTAssertNil(CalibrationProfile.load(from: d))
    }
}
