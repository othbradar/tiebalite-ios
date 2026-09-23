import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct R03HomeTests {
    @Test
    func successfulForumVisitKeepsPublicAvatarInExistingHistory() async throws {
        let repository = InMemoryBrowsingHistoryRepository()
        let store = BrowsingHistoryStore(repository: repository, clock: HarnessControlledClock())
        let route = try #require(ForumRoute(forumID: 818, forumName: "Fixture forum"))
        let avatar = "https://home.fixture.invalid/forum/818.png"
        let forum = ForumSummary(
            forumID: 818, name: "Fixture forum", slogan: nil, avatarResourceID: avatar,
            memberCount: 12, threadCount: 3, postCount: 4
        )
        await store.recordForum(route: route, forum: forum)
        let entry = try #require(store.entries.first)
        let encoded = try JSONEncoder().encode(entry)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["forumAvatarResourceID"] as? String == avatar)
        #expect(entry.identity == .forum(818))
    }

    @Test
    func recentProjectionIsForumOnlyBoundedNewestFirstAndKeepsBusinessRoutes() throws {
        var entries = try (1...25).map { id in
            try BrowsingHistoryEntry.forum(
                forumID: Int64(id), forumName: "Forum \(id)",
                visitedAt: Date(timeIntervalSince1970: Double(id))
            )
        }
        entries += [
            try .thread(threadID: 25, title: "A thread", forumName: nil, visitedAt: Date(timeIntervalSince1970: 100)),
            try .forum(forumID: 3, forumName: "Revisited", visitedAt: Date(timeIntervalSince1970: 101))
        ]
        let recent = RecentForum.project(entries, followedForums: [])
        #expect(recent.count == RecentForum.maximumCount)
        #expect(recent.first?.id == 3)
        #expect(recent.first?.name == "Revisited")
        #expect(recent[1].id == 25)
        #expect(Set(recent.map(\.id)).count == recent.count)
        #expect(recent.allSatisfy { $0.route.forumID?.rawValue == $0.id })
    }

    @Test
    func oldHistoryDecodesAndCanUseAnExistingFollowedAvatarWithoutInventingURLs() throws {
        let original = try BrowsingHistoryEntry.forum(
            forumID: 8, forumName: "Forum", visitedAt: Date(timeIntervalSince1970: 1)
        )
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        object.removeValue(forKey: "forumAvatarResourceID")
        let legacy = try JSONDecoder().decode(BrowsingHistoryEntry.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(legacy.forumAvatarResourceID == nil)
        let followed = forum(8)
        let recent = RecentForum.project([legacy], followedForums: [followed])
        #expect(recent.first?.avatarResource == followed.avatarResource)
        #expect(RecentForum.project([legacy], followedForums: []).first?.avatarResource == nil)
        let unsafe = try BrowsingHistoryEntry.forum(
            forumID: 8, forumName: "Forum", avatarResourceID: "http://home.fixture.invalid/avatar.png",
            visitedAt: Date(timeIntervalSince1970: 2)
        )
        #expect(unsafe.forumAvatarResourceID == nil)
    }

    @Test
    func revisitsPersistAvatarAndClearRemovesRecentProjection() async throws {
        let first = try BrowsingHistoryEntry.forum(
            forumID: 8, forumName: "Forum", avatarResourceID: "https://home.fixture.invalid/8.png",
            visitedAt: Date(timeIntervalSince1970: 1)
        )
        let repository = InMemoryBrowsingHistoryRepository()
        await repository.record(first)
        try await repository.record(.forum(forumID: 9, forumName: "Other", visitedAt: Date(timeIntervalSince1970: 2)))
        try await repository.record(.forum(forumID: 8, forumName: "Updated", visitedAt: Date(timeIntervalSince1970: 3)))
        let decoded = try JSONDecoder().decode(
            [BrowsingHistoryEntry].self, from: JSONEncoder().encode(await repository.load())
        )
        #expect(decoded.first?.forumAvatarResourceID == first.forumAvatarResourceID)
        #expect(decoded.first?.visitCount == 2)
        #expect(RecentForum.project(decoded, followedForums: []).map(\.id) == [8, 9])
        await repository.clear()
        #expect(RecentForum.project(await repository.load(), followedForums: []).isEmpty)
    }

    @Test
    func headerToggleAndRefreshRetainForumRowsAndDoNotOverwriteForumAnchor() throws {
        let forums = (1...500).map { forum(Int64($0)) }
        let history = try BrowsingHistoryEntry.forum(
            forumID: 1, forumName: "Forum", visitedAt: Date(timeIntervalSince1970: 1)
        )
        let recent = RecentForum.project([history], followedForums: forums)
        let before = FollowedForumsListPresentation(forums: forums, recent: recent, expanded: true)
        let updated = FollowedForumsListPresentation(
            forums: forums + [forums[0]], recent: recent, expanded: false, status: .loading
        )
        #expect(before.rows.suffix(500) == updated.rows.suffix(500))
        #expect(Set(updated.rows.map(\.id)).count == updated.rows.count)
        #expect(updated.forumAnchor(for: .forum(400)) == 400)
        for rowID in [nil, .recent, .heading, .status, .forum(-1)] as [FollowedForumsRowID?] {
            #expect(updated.forumAnchor(for: rowID) == nil)
        }
        #expect(updated.restoredRowID(for: 400) == .forum(400))
        #expect(updated.restoredRowID(for: 999) == nil)
    }

    @Test
    func aNewForumRouteVisitCanRecordAgainWhileProjectionKeepsItsClaim() async throws {
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let registry = AppFeatureStoreRegistry(
            fixtureDefaults: (),
            followedForumsStore: FollowedForumsStore(repository: FixtureFollowedForumsRepository()),
            recommendationsStore: RecommendationsStore(repository: FixtureRecommendationRepository()),
            makeThreadReaderStore: { ThreadReaderStore(threadID: $0, repository: FixtureThreadReaderRepository()) }
        )
        let navigation = AppNavigationStore()
        #expect(navigation.push(.forum(route), in: .followedForums))
        let store = registry.forumHomeStore(for: .followedForums, route: route)
        #expect(store.state.displayedForum == nil)
        await store.synchronize(with: route)
        #expect(store.state.displayedForum != nil)
        #expect(store.claimDisplayedForum(13_001))
        registry.retainFeatureStores(in: navigation.state)
        #expect(registry.forumHomeStore(for: .followedForums, route: route) === store)
        #expect(!store.claimDisplayedForum(13_001))
        registry.retainFeatureStores(in: AppNavigationState())
        let revisited = registry.forumHomeStore(for: .followedForums, route: route)
        #expect(revisited !== store)
        await revisited.synchronize(with: route)
        #expect(revisited.state.displayedForum != nil)
        #expect(revisited.claimDisplayedForum(13_001))
    }

    @Test
    func followedAvatarCanReuseOnlyTheSameForumsKnownHTTPSHistoryImage() throws {
        let history = try BrowsingHistoryEntry.forum(
            forumID: 8, forumName: "Forum", avatarResourceID: "https://home.fixture.invalid/8.png",
            visitedAt: Date(timeIntervalSince1970: 1)
        )
        let httpForum = FollowedForum(
            forumID: 8, name: "Forum", avatarResourceID: "http://home.fixture.invalid/8.png",
            hotCount: 1, memberCount: 2, threadCount: 3, levelID: 8, levelName: nil, isSignedToday: false
        )
        let recent = RecentForum.project([history], followedForums: [])
        let before = FollowedForumsListPresentation(forums: [httpForum, forum(9)], recent: [], expanded: true)
        let after = FollowedForumsListPresentation(forums: [httpForum, forum(9)], recent: recent, expanded: true)
        let original = try #require(before.rows.first { $0.id == .forum(8) })
        let updated = try #require(after.rows.first { $0.id == .forum(8) })
        #expect(original.avatarResource == nil)
        #expect(updated.avatarResource == recent[0].avatarResource)
        #expect(updated.id == original.id)
        #expect(updated != original)
        #expect(after.rows.first { $0.id == .forum(9) }?.avatarResource == forum(9).avatarResource)
    }

    @Test
    func heatUsesTheAndroidDecimalTruncationAndNeverMemberCount() {
        #expect(HomeForumNumber.text(9_999) == "9999")
        #expect(HomeForumNumber.text(10_000) == "1.0W")
        #expect(HomeForumNumber.text(29_999) == "2.9W")
        #expect(HomeForumNumber.text(285_678) == "28.5W")
        #expect(HomeForumNumber.text(10_000_000) == "1.0KW")
        #expect(HomeForumNumber.text(-1) == "0")
    }

    @Test
    func homeSearchUsesItsOwnExistingRootStackAndValidatesResultChains() throws {
        let store = AppNavigationStore()
        let forumRoute = try #require(ForumRoute(forumID: 8, forumName: "Forum"))
        let threadID = try #require(ThreadID(18))
        #expect(!store.push(.thread(threadID), in: .followedForums))
        #expect(store.push(.search, in: .followedForums))
        #expect(store.push(.forum(forumRoute), in: .followedForums))
        #expect(store.push(.thread(threadID), in: .followedForums))
        #expect(store.state.routes(for: .recommendations).isEmpty)
        #expect(store.state.routes(for: .followedForums) == [.search, .forum(forumRoute), .thread(threadID)])
        #expect(!RouteGrammar.isValid([.search, .search], for: .followedForums))
        #expect(store.push(.search, in: .followedForums))
        #expect(store.state.routes(for: .followedForums) == [.search])
    }

    private func forum(_ id: Int64) -> FollowedForum {
        FollowedForum(
            forumID: id, name: "Forum \(id)", avatarResourceID: "https://home.fixture.invalid/\(id).png",
            hotCount: 29_000, memberCount: 123_456, threadCount: 1, levelID: 14, levelName: nil, isSignedToday: false
        )
    }
}
