import Foundation
import CoreLocation
import MapKit

/// Finds places to pray near a coordinate with Apple Maps, and real
/// travel times with MKDirections. No API key; no invented data.
final class MosqueFinder {
    enum FinderError: Error { case noResults }

    /// Maps has no mosque category, so several plain-language queries.
    private let queries = ["mosque", "masjid", "musalla", "Islamic centre"]

    func nearby(to coord: CLLocationCoordinate2D, radiusMeters: CLLocationDistance = 5000) async throws -> [Mosque] {
        var lists: [[Mosque]] = []
        var lastError: Error?
        for q in queries {
            do { lists.append(try await search(q, near: coord, radius: radiusMeters)) } catch { lastError = error }
        }
        if lists.isEmpty, let lastError { throw lastError }
        return MosqueLibrary.merge(lists).filter { $0.distanceMeters <= radiusMeters }
    }

    func nearest(to coord: CLLocationCoordinate2D) async throws -> Mosque {
        guard let first = try await nearby(to: coord, radiusMeters: 3000).first else { throw FinderError.noResults }
        return first
    }

    private func search(_ query: String, near coord: CLLocationCoordinate2D, radius: CLLocationDistance) async throws -> [Mosque] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(center: coord, latitudinalMeters: radius * 2, longitudinalMeters: radius * 2)
        let response = try await MKLocalSearch(request: request).start()
        let origin = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return response.mapItems.map { item in
            let c = item.placemark.coordinate
            return Mosque(name: item.name ?? "Mosque", coordinate: c,
                          distanceMeters: origin.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude)),
                          phoneNumber: item.phoneNumber)
        }
    }

    /// Real travel time from Apple Maps; nil if Maps can't route it.
    func travelTime(from coord: CLLocationCoordinate2D, to mosque: Mosque, by transport: MKDirectionsTransportType) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: mosque.coordinate))
        request.transportType = transport
        return try? await MKDirections(request: request).calculateETA().expectedTravelTime
    }

    func openDirections(to mosque: Mosque, walking: Bool) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: mosque.coordinate))
        item.name = mosque.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: walking ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
