import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct Stage17ProjectionLifecycleTests {
    @Test
    func recommendationProjectionReplacementKeepsOneRequest() async throws {
        let repository = Stage17ControlledRecRepository()
        let store = RecommendationsStore(repository: repository)
        let visibility = Stage17Visibility()
        let host = UIHostingController(
            rootView: Stage17RecommendationProjectionHarness(
                visibility: visibility,
                store: store
            )
        )
        let window = Stage17ProjectionSupport.makeWindow(host: host)
        try await repository.waitForCallCount(1)

        visibility.isPresented = false
        window.layoutIfNeeded()
        await Stage17ProjectionSupport.settleChanges()
        visibility.isPresented = true
        window.layoutIfNeeded()
        await Stage17ProjectionSupport.settleChanges()

        #expect(await repository.callCount() == 1)
        try await repository.succeedLatest()
        await Stage17ProjectionSupport.waitUntil {
            store.state.items != nil
        }
        #expect(store.state.items?.isEmpty == false)
        visibility.isPresented = false
        window.rootViewController = nil
    }

    @Test
    func followedProjectionReplacementKeepsOneRequest() async throws {
        let repository = Stage17ControlledFollowedRepository()
        let store = FollowedForumsStore(repository: repository)
        let access = FollowedForumsSessionAccess.active(
            .candidate(OperationID(sequence: 17))
        )
        let visibility = Stage17Visibility()
        let host = UIHostingController(
            rootView: Stage17FollowedProjectionHarness(
                visibility: visibility,
                store: store,
                access: access
            )
        )
        let window = Stage17ProjectionSupport.makeWindow(host: host)
        try await repository.waitForCallCount(1)

        visibility.isPresented = false
        window.layoutIfNeeded()
        await Stage17ProjectionSupport.settleChanges()
        visibility.isPresented = true
        window.layoutIfNeeded()
        await Stage17ProjectionSupport.settleChanges()

        #expect(await repository.callCount() == 1)
        try await repository.succeedLatest(authentication: access)
        await Stage17ProjectionSupport.waitUntil {
            if case .loaded = store.state {
                return true
            }
            return false
        }
        guard case let .loaded(forums) = store.state else {
            Issue.record("Expected retained followed-forum result")
            return
        }
        #expect(!forums.isEmpty)
        visibility.isPresented = false
        window.rootViewController = nil
    }

    @Test
    func forumProjectionReplacementRecordsOneDisplayedVisit() async throws {
        let route = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        let store = ForumHomeStore(
            route: route,
            repository: FixtureForumHomeRepository()
        )
        await store.synchronize(with: route)
        let visits = Stage17AsyncCounter()
        let firstVisibility = Stage17Visibility()
        let firstHost = UIHostingController(
            rootView: Stage17ForumProjectionHarness(
                visibility: firstVisibility,
                store: store,
                route: route,
                onDisplayed: { _ in
                    await visits.increment()
                }
            )
        )
        let window = Stage17ProjectionSupport.makeWindow(host: firstHost)
        try await visits.waitForCount(1)

        firstVisibility.isPresented = false
        window.layoutIfNeeded()
        await Stage17ProjectionSupport.settleChanges()
        window.rootViewController = nil
        let secondVisibility = Stage17Visibility()
        let secondHost = UIHostingController(
            rootView: Stage17ForumProjectionHarness(
                visibility: secondVisibility,
                store: store,
                route: route,
                onDisplayed: { _ in
                    await visits.increment()
                }
            )
        )
        let secondWindow = Stage17ProjectionSupport.makeWindow(
            host: secondHost
        )
        await Stage17ProjectionSupport.settleChanges()

        #expect(await visits.count == 1)
        secondVisibility.isPresented = false
        secondWindow.rootViewController = nil
    }

    @Test
    func forumProjectionReplacementKeepsOneRequestAndStableThreads() async throws {
        let route = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        let repository = Stage17ControlledForumRepository()
        let store = ForumHomeStore(route: route, repository: repository)
        let visibility = Stage17Visibility()
        let host = UIHostingController(
            rootView: Stage17ForumProjectionHarness(
                visibility: visibility,
                store: store,
                route: route
            )
        )
        let window = Stage17ProjectionSupport.makeWindow(host: host)
        try await repository.waitForCallCount(1)

        visibility.isPresented = false
        window.layoutIfNeeded()
        await Stage17ProjectionSupport.settleChanges()
        visibility.isPresented = true
        window.layoutIfNeeded()
        await Stage17ProjectionSupport.settleChanges()

        #expect(await repository.callCount() == 1)
        try await repository.succeedLatest()
        await Stage17ProjectionSupport.waitUntil {
            store.state.snapshot != nil
        }

        #expect(store.route == route)
        #expect(
            store.state.snapshot?.threads.map(\.threadID)
                == FixtureReadingCatalog.forumThreadSeeds(for: route)
                    .map(\.threadID)
        )
        visibility.isPresented = false
        store.cancel()
        window.rootViewController = nil
    }

    @Test
    func threadProjectionReplacementKeepsOneRequestAndStablePosts() async throws {
        let threadID: Int64 = 140_006
        let repository = Stage17ControlledThreadRepository()
        let store = ThreadReaderStore(
            threadID: threadID,
            repository: repository
        )
        let visibility = Stage17Visibility()
        let host = UIHostingController(
            rootView: Stage17ThreadProjectionHarness(
                visibility: visibility,
                store: store
            )
        )
        let window = Stage17ProjectionSupport.makeWindow(host: host)
        try await repository.waitForCallCount(1)

        visibility.isPresented = false
        window.layoutIfNeeded()
        await Stage17ProjectionSupport.settleChanges()
        visibility.isPresented = true
        window.layoutIfNeeded()
        await Stage17ProjectionSupport.settleChanges()

        #expect(await repository.callCount() == 1)
        try await repository.succeedLatest()
        await Stage17ProjectionSupport.waitUntil {
            store.state.snapshot != nil
        }

        let expected = try await FixtureThreadReaderRepository().loadPage(
            .initial(threadID: threadID)
        )
        #expect(
            store.state.snapshot?.posts.map(\.document.source.postID)
                == expected.posts.map(\.document.source.postID)
        )
        visibility.isPresented = false
        store.cancel()
        window.rootViewController = nil
    }
}
