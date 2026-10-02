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
        static let forumSort = "dev.tiebalite.settings.forum-sort.v1"
        static let appearance = "dev.tiebalite.settings.appearance"
        static let readingTextSize = "dev.tiebalite.settings.reading-text-size"
    }

    private let suiteName: String?

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    func load() -> AppSettingsSnapshot {
        let defaults = resolvedDefaults
        var settings = AppSettingsSnapshot(
            appearance: defaults.string(forKey: Key.appearance)
                .flatMap(AppAppearancePreference.init(rawValue:)) ?? .system,
            readingTextSize: defaults.string(forKey: Key.readingTextSize)
                .flatMap(ReadingTextSizePreference.init(rawValue:)) ?? .standard
        )
        if let data = defaults.data(forKey: Key.forumSort),
           let preferences = try? JSONDecoder().decode(ForumSortPreferences.self, from: data) {
            settings.forumSort = preferences
        }
        return settings
    }

    func save(_ settings: AppSettingsSnapshot) throws {
        let forumSort = try JSONEncoder().encode(settings.forumSort)
        let defaults = resolvedDefaults
        defaults.set(forumSort, forKey: Key.forumSort)
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
