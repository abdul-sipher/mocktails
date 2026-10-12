import Foundation
import CoreLocation

/// The App Group shared by the app and its watch-face widgets.
enum AppGroup {
    static let id = "group.com.abdulelmir.sakinah"
    static let settingsKey = "prayerSettings.v1"

    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }

    static func loadSettings(from defaults: UserDefaults = AppGroup.defaults) -> PrayerSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let s = try? JSONDecoder().decode(PrayerSettings.self, from: data) else { return PrayerSettings() }
        return s
    }
}

/// What the app last knew about where the user is, for widgets and
/// background alert scheduling (neither can wait for a location fix).
struct SharedSnapshot: Codable, Equatable {
    static let key = "sharedSnapshot.v1"

    var latitude: Double
    var longitude: Double
    var mosqueName: String?
    var mosqueDistanceMeters: Double?
    var updatedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> SharedSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedSnapshot.self, from: data)
    }

    func save(to defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
