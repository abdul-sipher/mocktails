import Foundation
import CoreLocation

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<CLLocationCoordinate2D>.Continuation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 200
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func stream() -> AsyncStream<CLLocationCoordinate2D> {
        AsyncStream { continuation in
            self.continuation = continuation
            manager.startUpdatingLocation()
            continuation.onTermination = { [weak self] _ in
                self?.manager.stopUpdatingLocation()
            }
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let last = locs.last else { return }
        continuation?.yield(last.coordinate)
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) { }
}
