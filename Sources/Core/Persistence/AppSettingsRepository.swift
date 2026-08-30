import Foundation

actor InMemoryAppSettingsRepository: AppSettingsRepository {
    private var settings: AppSettingsSnapshot

    init(initial: AppSettingsSnapshot = .defaults) {
        settings = initial
    }

    func load() -> AppSettingsSnapshot {
        settings
    }

    func save(_ settings: AppSettingsSnapshot) {
        self.settings = settings
    }
}

actor UserDefaultsAppSettingsRepository: AppSettingsRepository {
    private enum Key {
        static let appearance = "dev.tiebalite.settings.appearance"
        static let readingTextSize = "dev.tiebalite.settings.reading-text-size"
    }

    private let suiteName: String?

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    func load() -> AppSettingsSnapshot {
        let defaults = resolvedDefaults
        return AppSettingsSnapshot(
            appearance: defaults.string(forKey: Key.appearance)
                .flatMap(AppAppearancePreference.init(rawValue:)) ?? .system,
            readingTextSize: defaults.string(forKey: Key.readingTextSize)
                .flatMap(ReadingTextSizePreference.init(rawValue:)) ?? .standard
        )
    }

    func save(_ settings: AppSettingsSnapshot) {
        let defaults = resolvedDefaults
        defaults.set(settings.appearance.rawValue, forKey: Key.appearance)
        defaults.set(
            settings.readingTextSize.rawValue,
            forKey: Key.readingTextSize
        )
    }

    private var resolvedDefaults: UserDefaults {
        guard let suiteName,
              let defaults = UserDefaults(suiteName: suiteName) else {
            return .standard
        }
        return defaults
    }
}
