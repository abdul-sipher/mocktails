import Foundation
import Combine

/// Persists `PrayerSettings` in the App Group so the watch-face widget
/// (Stage 2) reads the same values.
@MainActor
final class SettingsStore: ObservableObject {
    static let key = AppGroup.settingsKey

    private let defaults: UserDefaults

    @Published var settings: PrayerSettings {
        didSet { save() }
    }

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(PrayerSettings.self, from: data) {
            settings = saved
        } else {
            settings = PrayerSettings()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
