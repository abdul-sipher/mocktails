import Foundation

struct SalahSession: Identifiable, Codable {
    let id: UUID
    let prayer: PrayerName
    var rakahCount: Int
    var currentRakah: Int
    var currentSajdah: Int      // 0, 1 or 2 within current rakah
    var currentPosture: Posture
    var startedAt: Date
    var endedAt: Date?

    init(prayer: PrayerName, rakahCount: Int) {
        self.id = UUID()
        self.prayer = prayer
        self.rakahCount = rakahCount
        self.currentRakah = 1
        self.currentSajdah = 0
        self.currentPosture = .idle
        self.startedAt = Date()
    }
}

enum PrayerName: String, Codable, CaseIterable, Identifiable {
    case fajr, dhuhr, asr, maghrib, isha

    var id: String { rawValue }

    var defaultRakahs: Int {
        switch self {
        case .fajr: return 2
        case .dhuhr, .asr, .isha: return 4
        case .maghrib: return 3
        }
    }

    var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

struct PrayerTime: Codable, Identifiable {
    var id: PrayerName { name }
    let name: PrayerName
    let date: Date
}
