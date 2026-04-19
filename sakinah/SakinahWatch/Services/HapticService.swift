import Foundation
import WatchKit

final class HapticService {
    enum Cue {
        case lightTick
        case postureChange
        case sajdahOne
        case sajdahTwo
        case rakahComplete
        case salahComplete
        case wuduComplete
        case dhikrReminder
        case mosqueSuggestion
    }

    func play(_ cue: Cue) {
        let type: WKHapticType
        switch cue {
        case .lightTick:        type = .click
        case .postureChange:    type = .directionUp
        case .sajdahOne:        type = .notification
        case .sajdahTwo:        type = .notification
        case .rakahComplete:    type = .success
        case .salahComplete:    type = .success
        case .wuduComplete:     type = .success
        case .dhikrReminder:    type = .notification
        case .mosqueSuggestion: type = .directionUp
        }
        WKInterfaceDevice.current().play(type)

        // For rakah completion, double-tap so it's clearly distinct.
        if case .rakahComplete = cue {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
}
