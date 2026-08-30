import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsStore {
    private(set) var settings: AppSettingsSnapshot = .defaults
    private(set) var isLoaded = false
    private(set) var persistenceFailed = false

    private let repository: any AppSettingsRepository
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSave: AppSettingsSnapshot?

    init(repository: any AppSettingsRepository) {
        self.repository = repository
    }

    var appearance: AppAppearancePreference {
        settings.appearance
    }

    var readingTextSize: ReadingTextSizePreference {
        settings.readingTextSize
    }

    func loadIfNeeded() async {
        guard !isLoaded else {
            return
        }
        do {
            settings = try await repository.load()
            persistenceFailed = false
        } catch {
            settings = .defaults
            persistenceFailed = true
        }
        isLoaded = true
    }

    func setAppearance(_ value: AppAppearancePreference) {
        guard settings.appearance != value else {
            return
        }
        settings.appearance = value
        persistCurrentSettings()
    }

    func setReadingTextSize(_ value: ReadingTextSizePreference) {
        guard settings.readingTextSize != value else {
            return
        }
        settings.readingTextSize = value
        persistCurrentSettings()
    }

    func waitForPendingSave() async {
        await saveTask?.value
    }

    private func persistCurrentSettings() {
        pendingSave = settings
        guard saveTask == nil else {
            return
        }
        let repository = repository
        saveTask = Task { @MainActor [weak self] in
            await self?.runSaveLoop(repository: repository)
        }
    }

    private func runSaveLoop(
        repository: any AppSettingsRepository
    ) async {
        while let snapshot = pendingSave {
            pendingSave = nil
            do {
                try await repository.save(snapshot)
                if pendingSave == nil {
                    persistenceFailed = false
                }
            } catch {
                if pendingSave == nil {
                    persistenceFailed = true
                }
            }
        }
        saveTask = nil
    }
}

extension AppAppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    var title: String {
        switch self {
        case .system:
            "跟随系统"
        case .light:
            "浅色"
        case .dark:
            "深色"
        }
    }
}

extension ReadingTextSizePreference {
    var title: String {
        switch self {
        case .small:
            "小"
        case .standard:
            "标准"
        case .large:
            "大"
        }
    }
}
