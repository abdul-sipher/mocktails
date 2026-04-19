import Foundation
import CoreLocation
import MapKit

/// Finds mosques near a coordinate using MKLocalSearch.
/// On watchOS 9+, `MKLocalSearch` works against Apple Maps data and
/// does not require a separate API key.
final class MosqueFinder {
    enum FinderError: Error { case noResults }

    func nearby(to coord: CLLocationCoordinate2D, radiusMeters: CLLocationDistance = 3000) async throws -> [Mosque] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "mosque"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: coord,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )

        let response = try await MKLocalSearch(request: request).start()
        let origin = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let items = response.mapItems
            .map { item -> Mosque in
                let loc = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                return Mosque(
                    id: UUID(),
                    name: item.name ?? "Mosque",
                    coordinate: item.placemark.coordinate,
                    distanceMeters: origin.distance(from: loc),
                    phoneNumber: item.phoneNumber
                )
            }
            .sorted { $0.distanceMeters < $1.distanceMeters }
        return items
    }

    func nearest(to coord: CLLocationCoordinate2D) async throws -> Mosque {
        let list = try await nearby(to: coord)
        guard let first = list.first else { throw FinderError.noResults }
        return first
    }
}
