import Foundation
import CoreLocation

struct Mosque: Identifiable, Hashable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: CLLocationDistance
    let phoneNumber: String?

    static func == (lhs: Mosque, rhs: Mosque) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
