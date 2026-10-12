import Foundation

/// Postures detected during salah via wrist motion.
enum Posture: String, Codable, CaseIterable {
    case idle
    case qiyam      // standing, hands folded over chest
    case ruku       // bowing
    case qawmah     // standing up from ruku
    case sujood     // prostration
    case jalsa      // sitting between sajdahs / tashahhud
    case tashahhud  // final sitting
}

/// Steps of wudu tracked in order.
enum WuduStep: Int, Codable, CaseIterable, Identifiable {
    case niyyah
    case hands
    case mouth
    case nose
    case face
    case rightArm
    case leftArm
    case headAndEars
    case feet

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .niyyah:      return "Intention (niyyah)"
        case .hands:       return "Hands × 3"
        case .mouth:       return "Rinse mouth × 3"
        case .nose:        return "Rinse nose × 3"
        case .face:        return "Face × 3"
        case .rightArm:    return "Right arm to elbow × 3"
        case .leftArm:     return "Left arm to elbow × 3"
        case .headAndEars: return "Wipe head and ears"
        case .feet:        return "Feet to ankles × 3"
        }
    }

    var arabicHint: String {
        switch self {
        case .niyyah:      return "النية"
        case .hands:       return "اليدين"
        case .mouth:       return "المضمضة"
        case .nose:        return "الاستنشاق"
        case .face:        return "الوجه"
        case .rightArm:    return "اليد اليمنى"
        case .leftArm:     return "اليد اليسرى"
        case .headAndEars: return "مسح الرأس والأذنين"
        case .feet:        return "القدمين"
        }
    }

    /// Washes counted for this step (one hold or wipe, otherwise three).
    var target: Int {
        switch self {
        case .niyyah, .headAndEars: return 1
        default: return 3
        }
    }
}
