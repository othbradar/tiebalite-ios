import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsStore: ForumSortPreferenceProviding {
    private(set) var settings: AppSettingsSnapshot = .defaults
    private(set) var isLoaded = false
    private(set) var persistenceFailed = false

    private(set) var contentRequestDiagnostics = ""
    private(set) var imageRequestDiagnostics = ""
    private(set) var imageCacheBytes = 0
    private(set) var clearingImages = false
    private let imageCache: ProductionImageLoader?
    private let contentScheduler: ContentLoadScheduler?
    private let contentCache: ContentPageCache?
    private let repository: any AppSettingsRepository
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSave: AppSettingsSnapshot?

    init(
        repository: any AppSettingsRepository, contentScheduler: ContentLoadScheduler? = nil,
        contentCache: ContentPageCache? = nil, imageCache: ProductionImageLoader? = nil
    ) {
        self.repository = repository
        self.contentScheduler = contentScheduler
        self.contentCache = contentCache
        self.imageCache = imageCache
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

    func refreshContentDiagnostics() async {
        guard let contentScheduler, let contentCache else { return }
        let counts = await contentScheduler.diagnostics()
        let memory = await contentCache.memoryHits
        let disk = await contentCache.diskHits
        contentRequestDiagnostics = "cache=\(counts.cacheHits) foreground=\(counts.networkForeground)"
            + " prefetch=\(counts.networkSpeculative) merged=\(counts.merged) memory=\(memory) disk=\(disk)"
    }

    func setContentPrefetch(_ mode: ContentPrefetchMode) {
        settings.contentPrefetch = mode
        persistCurrentSettings()
    }

    func refreshImageCacheUsage() async {
        guard let imageCache else { return }
        let counts = await imageCache.imageCacheDiagnostics()
        imageCacheBytes = counts.diskBytes
        imageRequestDiagnostics = "images disk=\(counts.diskHits) network=\(counts.networkRequests) merged=\(counts.merged)"
    }

    func clearImageCache() async {
        guard !clearingImages, let imageCache else { return }
        clearingImages = true
        await imageCache.clearImageCache()
        await refreshImageCacheUsage()
        clearingImages = false
    }

    var forumSortPreferences: ForumSortPreferences { settings.forumSort }
    var defaultForumSort: ForumSortOrder { settings.forumSort.defaultOrder }

    func setDefaultForumSort(_ order: ForumSortOrder) {
        guard settings.forumSort.defaultOrder != order else { return }
        settings.forumSort.defaultOrder = order
        persistCurrentSettings()
    }

    func updateForumSort(_ order: ForumSortOrder?, for route: ForumRoute) {
        settings.forumSort.set(order, for: route)
        persistCurrentSettings()
    }

    func associateForumSort(route: ForumRoute, forumID: Int64, canonicalName: String) {
        let previous = settings.forumSort
        settings.forumSort.associate(route: route, forumID: forumID, canonicalName: canonicalName)
        if previous != settings.forumSort { persistCurrentSettings() }
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
