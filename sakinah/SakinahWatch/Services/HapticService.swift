import Foundation
import WatchKit

final class HapticService {
    enum Cue {
        case lightTick
        case postureChange
        case sajdahOne
        case sajdahTwo
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
        case .wuduComplete:     type = .success
        case .dhikrReminder:    type = .notification
        case .mosqueSuggestion: type = .directionUp
        }
        WKInterfaceDevice.current().play(type)
    }

    /// Buzzes `count` times, once per completed rakah.
    /// 1 buzz after rakah 1, 2 after rakah 2, and so on.
    /// Spacing is wide enough to feel as distinct pulses.
    func playRakahCount(_ count: Int) {
        let n = max(1, count)
        let spacing: TimeInterval = 0.45
        Task { @MainActor in
            for i in 0..<n {
                WKInterfaceDevice.current().play(.success)
                if i < n - 1 {
                    try? await Task.sleep(for: .milliseconds(Int(spacing * 1000)))
                }
            }
        }
    }
}
