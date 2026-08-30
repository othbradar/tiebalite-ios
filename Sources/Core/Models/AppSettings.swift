enum AppAppearancePreference: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

enum ReadingTextSizePreference: String, Codable, CaseIterable, Sendable {
    case small
    case standard
    case large
}

struct AppSettingsSnapshot: Codable, Equatable, Sendable {
    var appearance: AppAppearancePreference
    var readingTextSize: ReadingTextSizePreference

    static let defaults = AppSettingsSnapshot(
        appearance: .system,
        readingTextSize: .standard
    )
}

protocol AppSettingsRepository: Sendable {
    func load() async throws -> AppSettingsSnapshot
    func save(_ settings: AppSettingsSnapshot) async throws
}
