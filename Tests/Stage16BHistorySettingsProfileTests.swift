import Foundation
import Testing
@testable import TiebaLite

struct Stage16BHistoryTests {
    @Test
    func repeatedThreadMovesToFrontAndKeepsOneStableIdentity() async throws {
        let repository = InMemoryBrowsingHistoryRepository(maximumCount: 500)
        let firstDate = Date(timeIntervalSince1970: 1_000)
        let laterDate = Date(timeIntervalSince1970: 2_000)

        try await repository.record(.thread(
            threadID: 101,
            title: "First title",
            forumName: "Swift",
            visitedAt: firstDate
        ))
        try await repository.record(.forum(
            forumID: 202,
            forumName: "iOS",
            visitedAt: firstDate.addingTimeInterval(1)
        ))
        try await repository.record(.thread(
            threadID: 101,
            title: "Updated title",
            forumName: "Swift",
            visitedAt: laterDate
        ))

        let entries = await repository.load()
        #expect(entries.count == 2)
        #expect(entries.first?.identity == .thread(101))
        #expect(entries.first?.title == "Updated title")
        #expect(entries.first?.visitedAt == laterDate)
        #expect(entries.first?.visitCount == 2)
    }

    @Test
    func forumAndUserUseIndependentStableIdentities() async throws {
        let repository = InMemoryBrowsingHistoryRepository(maximumCount: 500)
        let date = Date(timeIntervalSince1970: 3_000)

        try await repository.record(.forum(
            forumID: 303,
            forumName: "Forum A",
            visitedAt: date
        ))
        try await repository.record(.forum(
            forumID: 303,
            forumName: "Forum B",
            visitedAt: date.addingTimeInterval(1)
        ))
        try await repository.record(.user(
            userID: 303,
            displayName: "User A",
            visitedAt: date.addingTimeInterval(2)
        ))
        try await repository.record(.user(
            userID: 303,
            displayName: "User B",
            visitedAt: date.addingTimeInterval(3)
        ))

        let entries = await repository.load()
        #expect(entries.map(\.identity) == [.user(303), .forum(303)])
        #expect(entries.first?.title == "User B")
        #expect(entries.first?.visitCount == 2)
        #expect(entries.last?.title == "Forum B吧")
    }

    @Test
    func repositoryEvictsOldestAndSupportsDeleteAndClear() async throws {
        #expect(JSONBrowsingHistoryRepository.defaultMaximumCount == 500)
        let repository = InMemoryBrowsingHistoryRepository(maximumCount: 2)
        for rawID in 1...3 {
            try await repository.record(.thread(
                threadID: Int64(rawID),
                title: "Thread \(rawID)",
                forumName: nil,
                visitedAt: Date(timeIntervalSince1970: TimeInterval(rawID))
            ))
        }

        let afterEviction = await repository.load()
        #expect(afterEviction.map(\.identity) == [
            .thread(3),
            .thread(2)
        ])
        await repository.delete(.thread(2))
        let afterDeletion = await repository.load()
        #expect(afterDeletion.map(\.identity) == [.thread(3)])
        await repository.clear()
        #expect(await repository.load().isEmpty)
    }

    @Test
    func jsonRepositoryRestoresFromAnAtomicApplicationSupportStyleFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("stage16b-history-json-repository")
        try? FileManager.default.removeItem(at: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("history.json")

        let first = JSONBrowsingHistoryRepository(
            fileURL: fileURL,
            maximumCount: 500
        )
        try await first.record(.thread(
            threadID: 404,
            title: "Persistent thread",
            forumName: "Fixture",
            visitedAt: Date(timeIntervalSince1970: 4_000)
        ))

        let rebuilt = JSONBrowsingHistoryRepository(
            fileURL: fileURL,
            maximumCount: 500
        )
        #expect(try await rebuilt.load().map(\.identity) == [.thread(404)])
    }

    @Test
    func historyDestinationsReuseExistingRoutes() throws {
        let date = Date(timeIntervalSince1970: 5_000)
        let thread = try BrowsingHistoryEntry.thread(
            threadID: 505,
            title: "Thread",
            forumName: "Fixture",
            visitedAt: date
        )
        let forum = try BrowsingHistoryEntry.forum(
            forumID: 606,
            forumName: "Fixture forum",
            visitedAt: date
        )
        let user = try BrowsingHistoryEntry.user(
            userID: 707,
            displayName: "Fixture user",
            visitedAt: date
        )

        #expect(thread.route == .thread(try #require(ThreadID(505))))
        #expect(forum.route == .forum(try #require(ForumRoute(
            forumID: 606,
            forumName: "Fixture forum"
        ))))
        #expect(user.route == .userProfile(try #require(UserProfileRoute(
            userID: 707,
            fallbackDisplayName: "Fixture user"
        ))))
    }

    @Test @MainActor
    func settingsClearEntryUsesTheHistoryStoreAndUpdatesItsCount() async throws {
        let repository = InMemoryBrowsingHistoryRepository()
        try await repository.record(.thread(
            threadID: 808,
            title: "Clear me",
            forumName: nil,
            visitedAt: Date(timeIntervalSince1970: 8_000)
        ))
        let store = BrowsingHistoryStore(
            repository: repository,
            clock: HarnessControlledClock()
        )
        await store.reload()
        #expect(store.count == 1)

        await store.clear()

        #expect(store.entries.isEmpty)
        #expect(await repository.load().isEmpty)
    }

}

struct Stage16BSettingsTests {
    @Test
    func unknownPersistedValuesFallBackToSafeDefaults() async {
        let suiteName = "Stage18SettingsTests.UnknownValues"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
        defer { defaults?.removePersistentDomain(forName: suiteName) }
        defaults?.set(
            "future-appearance",
            forKey: "dev.tiebalite.settings.appearance"
        )
        defaults?.set(
            "future-reading-size",
            forKey: "dev.tiebalite.settings.reading-text-size"
        )

        let repository = UserDefaultsAppSettingsRepository(
            suiteName: suiteName
        )

        #expect(await repository.load() == .defaults)
    }

    @Test
    func preferencesSurviveRepositoryReconstruction() async throws {
        let suiteName = "Stage16BSettingsTests.Persistence"
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(
            forName: suiteName
        )
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(
            forName: suiteName
        ) }
        let first = UserDefaultsAppSettingsRepository(suiteName: suiteName)
        let expected = AppSettingsSnapshot(
            appearance: .dark,
            readingTextSize: .large
        )
        await first.save(expected)

        let rebuilt = UserDefaultsAppSettingsRepository(suiteName: suiteName)
        #expect(await rebuilt.load() == expected)
    }

    @Test
    func readingSizeSelectsARealDesignSystemTypographyToken() {
        #expect(Typography.threadContentRole(for: .small) == .subheadline)
        #expect(Typography.threadContentRole(for: .standard) == .body)
        #expect(Typography.threadContentRole(for: .large) == .title)
    }

    @Test @MainActor
    func storeAppliesImmediatelyAndPersistsTheCombinedSnapshot() async {
        let repository = InMemoryAppSettingsRepository()
        let store = SettingsStore(repository: repository)
        await store.loadIfNeeded()

        store.setAppearance(.dark)
        store.setReadingTextSize(.large)
        await store.waitForPendingSave()

        #expect(store.appearance == .dark)
        #expect(store.readingTextSize == .large)
        #expect(await repository.load() == AppSettingsSnapshot(
            appearance: .dark,
            readingTextSize: .large
        ))
        #expect(AppAppearancePreference.system.colorScheme == nil)
        #expect(AppAppearancePreference.light.colorScheme == .light)
        #expect(AppAppearancePreference.dark.colorScheme == .dark)
    }

    @Test @MainActor
    func rapidChangesSerializeWritesAndNewestSnapshotWins() async throws {
        let repository = ControlledAppSettingsRepository()
        let store = SettingsStore(repository: repository)
        await store.loadIfNeeded()

        store.setAppearance(.dark)
        try await repository.waitForSaveCount(1)
        store.setReadingTextSize(.large)
        repository.releaseFirstSave()
        await store.waitForPendingSave()
        try await repository.waitForCompletionCount(2)

        #expect(await repository.load() == AppSettingsSnapshot(
            appearance: .dark,
            readingTextSize: .large
        ))
        #expect(await repository.maximumConcurrentSaveCount() == 1)
        #expect(await repository.savedSnapshots() == [
            AppSettingsSnapshot(
                appearance: .dark,
                readingTextSize: .standard
            ),
            AppSettingsSnapshot(
                appearance: .dark,
                readingTextSize: .large
            )
        ])
    }
}

struct Stage16BUserProfileTests {
    @Test
    func routeIdentityUsesOnlyValidatedStableUserID() throws {
        let first = try #require(UserProfileRoute(
            userID: 808,
            fallbackDisplayName: "Old name",
            portraitResourceID: "old"
        ))
        let updated = try #require(UserProfileRoute(
            userID: 808,
            fallbackDisplayName: "New name",
            portraitResourceID: "new"
        ))

        #expect(first == updated)
        #expect(Set([first, updated]).count == 1)
        #expect(UserProfileRoute(userID: 0, fallbackDisplayName: "Invalid") == nil)
    }

    @Test
    func fixtureRepositoryReturnsBasicProfileWithoutNetwork() async throws {
        let route = try #require(UserProfileRoute(
            userID: 909,
            fallbackDisplayName: "Fixture author"
        ))
        let profile = try await FixtureUserProfileRepository().loadProfile(
            route: route
        )

        #expect(profile.userID.rawValue == 909)
        #expect(profile.displayName == "Fixture author")
        #expect(profile.introduction?.isEmpty == false)
    }
}

@MainActor
struct Stage16BCompositionAndNavigationTests {
    @Test
    func fixtureLaunchesUseIndependentHistorySettingsAndNoLiveHTTP() async throws {
        let firstDescriptor = LaunchScenarioFactory.make(
            scenario: .fixtureReadingFlow
        )
        let secondDescriptor = LaunchScenarioFactory.make(
            scenario: .fixtureReadingFlow
        )
        let firstRoot = firstDescriptor.compositionRoot
        let secondRoot = secondDescriptor.compositionRoot
        let firstHistory = firstRoot.makeBrowsingHistoryStore()
        let secondHistory = secondRoot.makeBrowsingHistoryStore()
        let firstSettings = firstRoot.makeSettingsStore()
        let secondSettings = secondRoot.makeSettingsStore()
        let route = try #require(UserProfileRoute(
            userID: 1_010,
            fallbackDisplayName: "Fixture profile"
        ))

        let profileStore = firstRoot.makeUserProfileStore(route: route)
        await profileStore.loadIfNeeded()
        let profile = try #require(profileStore.state.profile)
        await firstHistory.recordUser(profile)
        await firstSettings.loadIfNeeded()
        firstSettings.setAppearance(.dark)
        await firstSettings.waitForPendingSave()
        await secondHistory.reload()
        await secondSettings.loadIfNeeded()

        #expect(firstHistory.entries.map(\.identity) == [.user(1_010)])
        #expect(secondHistory.entries.isEmpty)
        #expect(firstSettings.appearance == .dark)
        #expect(secondSettings.appearance == .system)
        #expect(firstRoot.authContextProvider.context() == .anonymous)
        #expect(secondRoot.authContextProvider.context() == .anonymous)
        let firstClient = try #require(
            firstRoot.environment.httpClient as? HarnessMockHTTPClient
        )
        let secondClient = try #require(
            secondRoot.environment.httpClient as? HarnessMockHTTPClient
        )
        #expect(await firstClient.events().isEmpty)
        #expect(await secondClient.events().isEmpty)
    }

    @Test
    func authorAndHistoryChainsReuseExistingNavigationStores() throws {
        let threadID = try #require(ThreadID(1_111))
        let profileRoute = try #require(UserProfileRoute(
            userID: 1_112,
            fallbackDisplayName: "Author"
        ))
        let forumRoute = try #require(ForumRoute(
            forumID: 1_113,
            forumName: "Fixture"
        ))

        #expect(RouteGrammar.isValid(
            [.thread(threadID), .userProfile(profileRoute)],
            for: .recommendations
        ))
        let navigation = AppNavigationStore()
        navigation.openSettingsRoute(.history)
        #expect(navigation.pushSettingsRoute(.content(.forum(forumRoute))))
        #expect(navigation.pushSettingsRoute(.content(.thread(threadID))))
        #expect(navigation.pushSettingsRoute(
            .content(.userProfile(profileRoute))
        ))
        #expect(navigation.state.settingsPath == [
            .history,
            .content(.forum(forumRoute)),
            .content(.thread(threadID)),
            .content(.userProfile(profileRoute))
        ])
    }
}

private extension UserProfileState {
    var profile: UserProfile? {
        guard case let .loaded(profile) = self else {
            return nil
        }
        return profile
    }
}

private enum ControlledAppSettingsRepositoryError: Error {
    case observerConflict
}

private actor ControlledAppSettingsRepository: AppSettingsRepository {
    private var stored = AppSettingsSnapshot.defaults
    private var saves: [AppSettingsSnapshot] = []
    private var completionCount = 0
    private var activeSaveCount = 0
    private var maximumActiveSaveCount = 0
    private let firstSaveGate = HarnessContinuationGate<Void>()
    private var saveObserver: (count: Int, gate: HarnessContinuationGate<Void>)?
    private var completionObserver:
        (count: Int, gate: HarnessContinuationGate<Void>)?

    func load() -> AppSettingsSnapshot {
        stored
    }

    func save(_ settings: AppSettingsSnapshot) async throws {
        saves.append(settings)
        activeSaveCount += 1
        maximumActiveSaveCount = max(
            maximumActiveSaveCount,
            activeSaveCount
        )
        resumeSaveObserverIfNeeded()
        if saves.count == 1 {
            try await firstSaveGate.wait()
        }
        stored = settings
        activeSaveCount -= 1
        completionCount += 1
        resumeCompletionObserverIfNeeded()
    }

    func waitForSaveCount(_ count: Int) async throws {
        guard saves.count < count else {
            return
        }
        guard saveObserver == nil else {
            throw ControlledAppSettingsRepositoryError.observerConflict
        }
        let gate = HarnessContinuationGate<Void>()
        saveObserver = (count, gate)
        try await gate.wait()
    }

    func waitForCompletionCount(_ count: Int) async throws {
        guard completionCount < count else {
            return
        }
        guard completionObserver == nil else {
            throw ControlledAppSettingsRepositoryError.observerConflict
        }
        let gate = HarnessContinuationGate<Void>()
        completionObserver = (count, gate)
        try await gate.wait()
    }

    nonisolated func releaseFirstSave() {
        firstSaveGate.succeed(())
    }

    func maximumConcurrentSaveCount() -> Int {
        maximumActiveSaveCount
    }

    func savedSnapshots() -> [AppSettingsSnapshot] {
        saves
    }

    private func resumeSaveObserverIfNeeded() {
        guard let observer = saveObserver,
              saves.count >= observer.count else {
            return
        }
        saveObserver = nil
        observer.gate.succeed(())
    }

    private func resumeCompletionObserverIfNeeded() {
        guard let observer = completionObserver,
              completionCount >= observer.count else {
            return
        }
        completionObserver = nil
        observer.gate.succeed(())
    }
}
