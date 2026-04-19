import Foundation

struct Ayah: Codable, Identifiable, Hashable {
    var id: String { "\(surah):\(number)" }
    let surah: Int
    let surahName: String
    let number: Int
    let arabic: String
    let translation: String
    /// Hour-of-day windows this ayah is suggested for (0-23).
    let hours: [Int]
}
