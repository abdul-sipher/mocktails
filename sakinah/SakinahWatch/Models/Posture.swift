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
    case handsThrice
    case mouthThrice
    case noseThrice
    case faceThrice
    case armsThrice
    case headWipe
    case earsWipe
    case feetThrice

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .niyyah:      return "Niyyah"
        case .handsThrice: return "Hands × 3"
        case .mouthThrice: return "Mouth × 3"
        case .noseThrice:  return "Nose × 3"
        case .faceThrice:  return "Face × 3"
        case .armsThrice:  return "Arms to elbows × 3"
        case .headWipe:    return "Wipe head"
        case .earsWipe:    return "Wipe ears"
        case .feetThrice:  return "Feet to ankles × 3"
        }
    }

    var arabicHint: String {
        switch self {
        case .niyyah:      return "النية"
        case .handsThrice: return "اليدين"
        case .mouthThrice: return "المضمضة"
        case .noseThrice:  return "الاستنشاق"
        case .faceThrice:  return "الوجه"
        case .armsThrice:  return "الذراعين"
        case .headWipe:    return "مسح الرأس"
        case .earsWipe:    return "مسح الأذنين"
        case .feetThrice:  return "القدمين"
        }
    }
}
