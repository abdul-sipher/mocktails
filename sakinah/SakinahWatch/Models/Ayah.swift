import Foundation

struct Ayah: Codable, Identifiable, Hashable {
    var id: String { "\(surah):\(number)" }
    let surah: Int
    let surahName: String
    let number: Int
    let arabic: String
    let translation: String
    /// True when only part of the verse is shown.
    var excerpt: Bool?
    /// Hour-of-day windows this ayah is suggested for (0-23).
    let hours: [Int]
}
