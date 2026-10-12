import XCTest

private final class FakeHaptics: SalahHaptics {
    var ticks = 0
    var rakahBuzzes: [Int] = []
    func tick() { ticks += 1 }
    func rakahCompleted(_ rakah: Int) { rakahBuzzes.append(rakah) }
}

@MainActor
final class SalahTrackerTests: XCTestCase {
    func testTwoSajdahsCompleteARakahWithNBuzzes() {
        let h = FakeHaptics()
        let t = SalahTracker(prayer: .maghrib, rakahCount: 3, haptics: h)
        t.start()
        t.recordSajdah()
        XCTAssertEqual(t.sajdah, 1)
        XCTAssertEqual(h.ticks, 1)
        t.recordSajdah()
        XCTAssertEqual(t.currentRakah, 2)
        XCTAssertEqual(t.sajdah, 0)
        XCTAssertEqual(h.rakahBuzzes, [1])
        t.recordSajdah(); t.recordSajdah()
        XCTAssertEqual(h.rakahBuzzes, [1, 2], "buzz count equals the rakah just completed")
    }

    func testFinalRakahFinishes() {
        let t = SalahTracker(prayer: .fajr, rakahCount: 2, haptics: nil)
        t.start()
        for _ in 0..<4 { t.recordSajdah() }
        XCTAssertEqual(t.status, .finished)
        XCTAssertEqual(t.completedRakahs, 2)
        XCTAssertNotNil(t.endedAt)
    }

    func testTapsIgnoredUnlessRunning() {
        let t = SalahTracker(prayer: .isha, rakahCount: 4, haptics: nil)
        t.recordSajdah()
        XCTAssertEqual(t.sajdah, 0, "not started")
        t.start(); t.pause(); t.recordSajdah()
        XCTAssertEqual(t.sajdah, 0, "paused")
        t.resume(); t.recordSajdah()
        XCTAssertEqual(t.sajdah, 1)
    }

    func testHapticsOffMeansSilent() {
        let t = SalahTracker(prayer: .dhuhr, rakahCount: 4, haptics: nil)
        t.start(); t.recordSajdah(); t.recordSajdah()
        XCTAssertEqual(t.currentRakah, 2)
    }

    func testUndoAcrossRakahBoundary() {
        let t = SalahTracker(prayer: .asr, rakahCount: 4, haptics: nil)
        t.start()
        t.recordSajdah(); t.recordSajdah()   // rakah 1 done
        t.undoSajdah()
        XCTAssertEqual(t.currentRakah, 1)
        XCTAssertEqual(t.sajdah, 1)
        XCTAssertEqual(t.completedRakahs, 0)
    }

    func testAdjustClampsAndReviewCorrects() {
        let t = SalahTracker(prayer: .maghrib, rakahCount: 3, haptics: nil)
        t.start()
        t.adjustRakah(by: 5)
        XCTAssertEqual(t.currentRakah, 3)
        t.adjustRakah(by: -9)
        XCTAssertEqual(t.currentRakah, 1)
        t.finish()
        t.correctCompleted(to: 7)
        XCTAssertEqual(t.completedRakahs, 3)
    }

    func testResetAndCustomLength() {
        let t = SalahTracker(prayer: nil, rakahCount: 40, haptics: nil)
        XCTAssertEqual(t.rakahCount, SalahTracker.rakahRange.upperBound)
        t.start(); t.recordSajdah(); t.reset()
        XCTAssertEqual(t.status, .ready)
        XCTAssertEqual(t.sajdah, 0)
        XCTAssertNil(t.startedAt)
    }
}
