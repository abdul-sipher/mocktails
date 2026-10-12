import XCTest
import CoreLocation

final class MosqueLibraryTests: XCTestCase {
    private func m(_ name: String, _ lat: Double, _ lon: Double, _ d: Double) -> Mosque {
        Mosque(name: name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), distanceMeters: d, phoneNumber: nil)
    }

    func testMergeDropsDuplicatesAcrossQueriesNearestFirst() {
        let a = m("Lakemba Mosque", -33.9200, 151.0750, 300)
        let aAgain = m("Lakemba Mosque", -33.92003, 151.07502, 302)   // same place, other query
        let b = m("Iqra Centre", -33.9190, 151.0740, 150)
        let merged = MosqueLibrary.merge([[a, b], [aAgain]])
        XCTAssertEqual(merged.map(\.name), ["Iqra Centre", "Lakemba Mosque"])
    }

    func testIdsAreStableAcrossSearches() {
        XCTAssertEqual(m("X", -33.92, 151.07, 10).id, m("X", -33.92, 151.07, 999).id)
    }

    func testFavouritesHomeWorkRoundTrip() {
        let name = "Lib-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        var lib = MosqueLibrary()
        let x = m("X", -33.92, 151.07, 10)
        lib.toggleFavourite(x)
        lib.home = x
        lib.cached = [x]
        lib.cachedAt = Date(timeIntervalSince1970: 1_000)
        lib.save(to: d)
        let back = MosqueLibrary.load(from: d)
        XCTAssertTrue(back.isFavourite(x))
        XCTAssertEqual(back.home, x)
        XCTAssertEqual(back.cachedAt, lib.cachedAt)
        var again = back
        again.toggleFavourite(x)
        XCTAssertFalse(again.isFavourite(x))
    }
}
