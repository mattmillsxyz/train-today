import Foundation

/// `PlanSettings` persisted to `UserDefaults` as JSON.
///
/// A single blob rather than a key per field: the settings are always read and
/// written together, and one decode keeps `seed` and `sports` from ever drifting
/// apart mid-migration.
@Observable
final class SettingsStore {
    private static let key = "trainToday.planSettings"

    private let defaults: UserDefaults

    var settings: PlanSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(PlanSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    /// Throws away everything and re-runs onboarding with a fresh shuffle.
    func reset() {
        settings = .default
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
