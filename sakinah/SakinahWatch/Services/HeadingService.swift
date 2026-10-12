import Foundation
import CoreLocation

/// Compass heading for the Qibla screen. Prefers true north (needs a
/// location fix); falls back to magnetic north and says so.
@MainActor
final class HeadingService: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Source { case trueNorth, magneticNorth }

    @Published private(set) var heading: Double?
    @Published private(set) var source: Source = .trueNorth
    /// Degrees of uncertainty; nil when unknown.
    @Published private(set) var accuracy: Double?

    let isAvailable = CLLocationManager.headingAvailable()
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1
    }

    func start() {
        guard isAvailable else { return }
        manager.startUpdatingLocation()   // true heading needs a location
        manager.startUpdatingHeading()
    }

    func stop() {
        manager.stopUpdatingHeading()
        manager.stopUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading h: CLHeading) {
        let trueHeading = h.trueHeading
        let magnetic = h.magneticHeading
        let acc = h.headingAccuracy
        Task { @MainActor in
            if trueHeading >= 0 {
                self.heading = trueHeading
                self.source = .trueNorth
            } else {
                self.heading = magnetic
                self.source = .magneticNorth
            }
            self.accuracy = acc >= 0 ? acc : nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
