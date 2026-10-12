import Foundation
import CoreLocation

/// A place to pray found through Apple Maps. Iqamah and Jumuʿah times
/// are not part of Maps data, so they are absent rather than guessed.
struct Mosque: Identifiable, Hashable, Codable {
    /// Stable across searches (name + rounded position), so favourites stick.
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    /// Distance from where the search was made.
    var distanceMeters: CLLocationDistance
    let phoneNumber: String?

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    init(name: String, coordinate: CLLocationCoordinate2D, distanceMeters: CLLocationDistance, phoneNumber: String?) {
        self.id = Mosque.makeID(name: name, coordinate: coordinate)
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.distanceMeters = distanceMeters
        self.phoneNumber = phoneNumber
    }

    static func makeID(name: String, coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%@|%.4f|%.4f", name.lowercased(), coordinate.latitude, coordinate.longitude)
    }

    func distance(from c: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude).distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
    }

    static func == (lhs: Mosque, rhs: Mosque) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Favourites, home/work prayer places and the last search, on this watch.
struct MosqueLibrary: Codable, Equatable {
    var favourites: [Mosque] = []
    var home: Mosque?
    var work: Mosque?
    var cached: [Mosque] = []
    var cachedAt: Date?

    static let key = "mosqueLibrary.v1"

    func isFavourite(_ m: Mosque) -> Bool { favourites.contains(m) }

    mutating func toggleFavourite(_ m: Mosque) {
        if let i = favourites.firstIndex(of: m) { favourites.remove(at: i) } else { favourites.append(m) }
    }

    /// Merge results from several queries: drop duplicates, nearest first.
    static func merge(_ lists: [[Mosque]]) -> [Mosque] {
        var seen = Set<String>()
        var out: [Mosque] = []
        for m in lists.flatMap({ $0 }).sorted(by: { $0.distanceMeters < $1.distanceMeters }) {
            // Same place under two queries can differ slightly in position.
            let key = m.name.lowercased()
            let near = out.contains { $0.name.lowercased() == key && $0.distance(from: m.coordinate) < 60 }
            if !near && seen.insert(m.id).inserted { out.append(m) }
        }
        return out
    }

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> MosqueLibrary {
        guard let data = defaults.data(forKey: key),
              let lib = try? JSONDecoder().decode(MosqueLibrary.self, from: data) else { return MosqueLibrary() }
        return lib
    }

    func save(to defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
