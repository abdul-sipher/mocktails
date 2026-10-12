import Foundation

/// The time in which a prayer may be prayed. `preferredEnd` marks where
/// the preferred time stops before the window itself closes (Isha).
struct PrayerWindow: Equatable {
    let prayer: PrayerName
    let start: Date
    let end: Date
    let preferredEnd: Date?
}

/// A span in which voluntary prayer is disliked. Minute values are
/// approximate and on the scholar-check list.
struct MakruhPeriod: Equatable, Identifiable {
    var id: String { title }
    let title: String
    let start: Date
    let end: Date
}

/// One calendar day of prayer times at one place.
struct DayTimetable: Equatable {
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date
    /// Fajr of the following day; closes the Isha window.
    let nextFajr: Date
    /// Midpoint of Maghrib and next Fajr; Isha is preferred before it.
    let middleOfNight: Date
    let lastThirdOfNight: Date
    let isFriday: Bool

    var prayers: [PrayerTime] {
        PrayerName.allCases.map { PrayerTime(name: $0, date: time(of: $0)) }
    }

    func time(of prayer: PrayerName) -> Date {
        switch prayer {
        case .fajr:    return fajr
        case .dhuhr:   return dhuhr
        case .asr:     return asr
        case .maghrib: return maghrib
        case .isha:    return isha
        }
    }

    /// First prayer starting after `now`; after Isha, tomorrow's Fajr.
    func next(after now: Date) -> PrayerTime {
        prayers.first { $0.date > now } ?? PrayerTime(name: .fajr, date: nextFajr)
    }

    /// Fajr ends at sunrise, so sunrise → Dhuhr has no prayer window.
    var windows: [PrayerWindow] {
        [
            PrayerWindow(prayer: .fajr, start: fajr, end: sunrise, preferredEnd: nil),
            PrayerWindow(prayer: .dhuhr, start: dhuhr, end: asr, preferredEnd: nil),
            PrayerWindow(prayer: .asr, start: asr, end: maghrib, preferredEnd: nil),
            PrayerWindow(prayer: .maghrib, start: maghrib, end: isha, preferredEnd: nil),
            PrayerWindow(prayer: .isha, start: isha, end: nextFajr, preferredEnd: middleOfNight)
        ]
    }

    func window(at now: Date) -> PrayerWindow? {
        windows.first { $0.start <= now && now < $0.end }
    }

    var makruhPeriods: [MakruhPeriod] {
        [
            MakruhPeriod(title: "Sunrise", start: sunrise, end: sunrise.addingTimeInterval(15 * 60)),
            MakruhPeriod(title: "Zawal, before Dhuhr", start: dhuhr.addingTimeInterval(-5 * 60), end: dhuhr),
            MakruhPeriod(title: "Before sunset", start: maghrib.addingTimeInterval(-15 * 60), end: maghrib)
        ]
    }
}

extension PrayerName {
    /// Dhuhr is shown as Jumuʿah on Fridays.
    func displayTitle(isFriday: Bool) -> String {
        self == .dhuhr && isFriday ? "Jumuʿah" : title
    }
}
