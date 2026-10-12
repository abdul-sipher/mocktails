import XCTest
import CoreLocation
import Adhan

final class QiblaTests: XCTestCase {
    func testShortestTurn() {
        XCTAssertEqual(QiblaMath.turn(qibla: 277, heading: 270), .right(7))
        XCTAssertEqual(QiblaMath.turn(qibla: 10, heading: 350), .right(20), "wraps through north")
        XCTAssertEqual(QiblaMath.turn(qibla: 350, heading: 10), .left(20))
        XCTAssertEqual(QiblaMath.turn(qibla: 100, heading: 290), .right(170))
        XCTAssertEqual(QiblaMath.turn(qibla: 100, heading: 260), .left(160))
        XCTAssertEqual(QiblaMath.turn(qibla: 277, heading: 274), .aligned)
    }

    func testSydneyQiblaBearingFromAdhan() {
        // Sydney faces roughly west-north-west (about 277° from true north).
        let q = Qibla(coordinates: Coordinates(latitude: -33.9205, longitude: 151.0756)).direction
        XCTAssertEqual(q, 277, accuracy: 2)
        XCTAssertEqual(QiblaMath.cardinal(q), "W")
    }

    func testDistanceToMakkahFromSydney() {
        let km = QiblaMath.distanceToMakkah(from: CLLocationCoordinate2D(latitude: -33.9205, longitude: 151.0756)) / 1000
        XCTAssertEqual(km, 13_400, accuracy: 200)
    }

    func testCanIMakeIt() {
        let now = Date()
        let start = now.addingTimeInterval(12 * 60)
        let yes = ArrivalAdvice.advise(prayer: .asr, prayerStart: start, windowEnd: nil, travel: 7 * 60, mode: "Walking", now: now)!
        XCTAssertTrue(yes.canMakeStart)
        XCTAssertEqual(yes.headline, "Asr begins in 12 min. Walking takes 7 min — you can make it.")
        let no = ArrivalAdvice.advise(prayer: .asr, prayerStart: start, windowEnd: nil, travel: 20 * 60, mode: "Walking", now: now)!
        XCTAssertFalse(no.canMakeStart)
        XCTAssertNil(ArrivalAdvice.advise(prayer: .asr, prayerStart: start, windowEnd: nil, travel: nil, mode: "Walking", now: now),
                     "no ETA, no advice")
    }

    func testAlreadyStartedUsesWindowEnd() {
        let now = Date()
        let a = ArrivalAdvice.advise(prayer: .dhuhr, prayerStart: now.addingTimeInterval(-600),
                                     windowEnd: now.addingTimeInterval(3600), travel: 300, mode: "Driving", now: now)
        XCTAssertNotNil(a)
        XCTAssertNil(ArrivalAdvice.advise(prayer: .dhuhr, prayerStart: now.addingTimeInterval(-600),
                                          windowEnd: now.addingTimeInterval(60), travel: 300, mode: "Driving", now: now))
    }
}
