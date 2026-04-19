import Foundation

/// Loads ayat from the bundled `Ayat.json` and selects one appropriate
/// for the current hour / prayer window.
final class QuranService {
    private lazy var ayat: [Ayah] = load()

    func ayahForCurrentHour(date: Date = Date()) -> Ayah? {
        let hour = Calendar.current.component(.hour, from: date)
        let candidates = ayat.filter { $0.hours.contains(hour) }
        return candidates.randomElement() ?? ayat.randomElement()
    }

    func ayahFor(prayer: PrayerName) -> Ayah? {
        let hoursByPrayer: [PrayerName: [Int]] = [
            .fajr:    [4, 5, 6],
            .dhuhr:   [12, 13],
            .asr:     [15, 16],
            .maghrib: [18, 19],
            .isha:    [20, 21]
        ]
        guard let hours = hoursByPrayer[prayer] else { return nil }
        let subset = ayat.filter { !Set($0.hours).isDisjoint(with: Set(hours)) }
        return subset.randomElement()
    }

    private func load() -> [Ayah] {
        guard
            let url = Bundle.main.url(forResource: "Ayat", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([Ayah].self, from: data)
        else { return [] }
        return decoded
    }
}
