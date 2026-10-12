import Foundation
import Adhan

/// School of fiqh. Stored on its own: it does not set the calculation
/// method, and only suggests (never forces) the Asr choice.
enum Madhhab: String, Codable, CaseIterable, Identifiable {
    case hanafi, shafii, maliki, hanbali

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hanafi:  return "Hanafi"
        case .shafii:  return "Shafiʿi"
        case .maliki:  return "Maliki"
        case .hanbali: return "Hanbali"
        }
    }

    /// Asr suggested when the madhhab is first chosen.
    var suggestedAsr: AsrSchool { self == .hanafi ? .hanafi : .standard }
}

/// When Asr begins: shadow equal to the object (standard) or twice it (Hanafi).
enum AsrSchool: String, Codable, CaseIterable, Identifiable {
    case standard, hanafi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .hanafi:   return "Hanafi"
        }
    }

    var detail: String {
        switch self {
        case .standard: return "Shadow equals object length (Shafiʿi, Maliki, Hanbali)"
        case .hanafi:   return "Shadow twice object length (later)"
        }
    }

    var adhan: Madhab { self == .hanafi ? .hanafi : .shafi }
}

/// How Fajr and Isha are found where the sun barely sets or rises.
enum HighLatitudeChoice: String, Codable, CaseIterable, Identifiable {
    case auto, middleOfTheNight, seventhOfTheNight, twilightAngle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:              return "Automatic"
        case .middleOfTheNight:  return "Middle of the night"
        case .seventhOfTheNight: return "Seventh of the night"
        case .twilightAngle:     return "Twilight angle"
        }
    }

    /// nil lets Adhan pick its recommended rule for the location.
    var adhan: HighLatitudeRule? {
        switch self {
        case .auto:              return nil
        case .middleOfTheNight:  return .middleOfTheNight
        case .seventhOfTheNight: return .seventhOfTheNight
        case .twilightAngle:     return .twilightAngle
        }
    }
}

enum Wrist: String, Codable, CaseIterable, Identifiable {
    case left, right
    var id: String { rawValue }
    var title: String { self == .left ? "Left" : "Right" }
}

struct PrayerSettings: Codable, Equatable {
    var method: CalculationMethod = .muslimWorldLeague
    var madhhab: Madhhab = .shafii
    var asr: AsrSchool = .standard
    /// Minutes added to each prayer, keyed by `PrayerName.rawValue`.
    var offsets: [String: Int] = [:]
    var highLatitude: HighLatitudeChoice = .auto
    var wrist: Wrist = .left
    var rakahHaptics = true
    var calmReminders = false
    var hasChosenMethod = false
    /// Notification at the start of each prayer.
    var prayerAlerts = true
    /// Heads-up before each prayer, in minutes; 0 = off.
    var headsUpMinutes = 10
    /// Name the nearest mosque in the heads-up.
    var mosqueNudge = true
    /// Add "make wudu before you leave" to the heads-up when wudu is not marked.
    var wuduReminder = true
    /// Buzz once when the Qibla screen lines up.
    var qiblaHaptic = true
    /// Days added to the Umm al-Qura Hijri date to match local sighting.
    var hijriOffset = 0
    /// Don't keep any record of salah sessions.
    var privacyMode = false
    /// Minimal, dim screens during salah.
    var khushuMode = false
    /// Save finished salah as mindful minutes in Health (opt-in).
    var mindfulMinutes = false
    /// Travelling: Dhuhr, Asr and Isha default to two rakʿāt.
    var travelling = false
    /// Daily reminder while prayers are owed.
    var qadaReminder = false
    /// Rakah buzzes as gentle taps instead of strong pulses (still N of them).
    var gentleBuzz = false

    static let offsetRange = -30...30

    init() {}

    func offset(for prayer: PrayerName) -> Int { offsets[prayer.rawValue] ?? 0 }

    mutating func setOffset(_ minutes: Int, for prayer: PrayerName) {
        let clamped = min(max(minutes, Self.offsetRange.lowerBound), Self.offsetRange.upperBound)
        offsets[prayer.rawValue] = clamped == 0 ? nil : clamped
    }

    /// Rakʿāt to start with for a prayer, shortened (qasr) when travelling.
    func defaultRakahs(for prayer: PrayerName) -> Int {
        travelling && [.dhuhr, .asr, .isha].contains(prayer) ? 2 : prayer.defaultRakahs
    }

    /// Method suggested from the device's region; the user confirms it.
    static func suggestedMethod(regionCode: String?) -> CalculationMethod {
        switch regionCode?.uppercased() {
        case "US", "CA":             return .northAmerica
        case "SA":                   return .ummAlQura
        case "EG":                   return .egyptian
        case "PK", "IN", "BD", "AF": return .karachi
        case "AE":                   return .dubai
        case "KW":                   return .kuwait
        case "QA":                   return .qatar
        case "SG", "MY", "ID", "BN": return .singapore
        case "TR":                   return .turkey
        case "IR":                   return .tehran
        default:                     return .muslimWorldLeague
        }
    }

    // Field-by-field decoding with defaults: a setting added in a later
    // version, or one that fails to decode, never resets the others.
    private enum CodingKeys: String, CodingKey {
        case method, madhhab, asr, offsets, highLatitude, wrist, rakahHaptics, calmReminders, hasChosenMethod
        case prayerAlerts, headsUpMinutes, mosqueNudge, wuduReminder, qiblaHaptic, hijriOffset
        case privacyMode, khushuMode, mindfulMinutes, travelling, qadaReminder, gentleBuzz
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PrayerSettings()
        method = (try? c.decodeIfPresent(CalculationMethod.self, forKey: .method)) ?? d.method
        madhhab = (try? c.decodeIfPresent(Madhhab.self, forKey: .madhhab)) ?? d.madhhab
        asr = (try? c.decodeIfPresent(AsrSchool.self, forKey: .asr)) ?? d.asr
        offsets = (try? c.decodeIfPresent([String: Int].self, forKey: .offsets)) ?? d.offsets
        highLatitude = (try? c.decodeIfPresent(HighLatitudeChoice.self, forKey: .highLatitude)) ?? d.highLatitude
        wrist = (try? c.decodeIfPresent(Wrist.self, forKey: .wrist)) ?? d.wrist
        rakahHaptics = (try? c.decodeIfPresent(Bool.self, forKey: .rakahHaptics)) ?? d.rakahHaptics
        calmReminders = (try? c.decodeIfPresent(Bool.self, forKey: .calmReminders)) ?? d.calmReminders
        hasChosenMethod = (try? c.decodeIfPresent(Bool.self, forKey: .hasChosenMethod)) ?? d.hasChosenMethod
        prayerAlerts = (try? c.decodeIfPresent(Bool.self, forKey: .prayerAlerts)) ?? d.prayerAlerts
        headsUpMinutes = (try? c.decodeIfPresent(Int.self, forKey: .headsUpMinutes)) ?? d.headsUpMinutes
        mosqueNudge = (try? c.decodeIfPresent(Bool.self, forKey: .mosqueNudge)) ?? d.mosqueNudge
        wuduReminder = (try? c.decodeIfPresent(Bool.self, forKey: .wuduReminder)) ?? d.wuduReminder
        qiblaHaptic = (try? c.decodeIfPresent(Bool.self, forKey: .qiblaHaptic)) ?? d.qiblaHaptic
        hijriOffset = (try? c.decodeIfPresent(Int.self, forKey: .hijriOffset)) ?? d.hijriOffset
        privacyMode = (try? c.decodeIfPresent(Bool.self, forKey: .privacyMode)) ?? d.privacyMode
        khushuMode = (try? c.decodeIfPresent(Bool.self, forKey: .khushuMode)) ?? d.khushuMode
        mindfulMinutes = (try? c.decodeIfPresent(Bool.self, forKey: .mindfulMinutes)) ?? d.mindfulMinutes
        travelling = (try? c.decodeIfPresent(Bool.self, forKey: .travelling)) ?? d.travelling
        qadaReminder = (try? c.decodeIfPresent(Bool.self, forKey: .qadaReminder)) ?? d.qadaReminder
        gentleBuzz = (try? c.decodeIfPresent(Bool.self, forKey: .gentleBuzz)) ?? d.gentleBuzz
    }
}

extension CalculationMethod: Identifiable {
    public var id: String { rawValue }

    /// Methods offered in the UI (`.other` needs custom angles).
    static var selectable: [CalculationMethod] { allCases.filter { $0 != .other } }

    var title: String {
        switch self {
        case .muslimWorldLeague:     return "Muslim World League"
        case .egyptian:              return "Egyptian General Authority"
        case .karachi:               return "Karachi (Univ. of Islamic Sciences)"
        case .ummAlQura:             return "Umm al-Qura (Makkah)"
        case .dubai:                 return "Dubai"
        case .moonsightingCommittee: return "Moonsighting Committee"
        case .northAmerica:          return "ISNA (North America)"
        case .kuwait:                return "Kuwait"
        case .qatar:                 return "Qatar"
        case .singapore:             return "Singapore (MUIS)"
        case .tehran:                return "Tehran (Univ. of Tehran)"
        case .turkey:                return "Turkey (Diyanet)"
        case .other:                 return "Custom"
        }
    }
}
