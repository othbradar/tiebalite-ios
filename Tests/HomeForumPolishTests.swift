import SwiftUI
import Testing
@testable import TiebaLite
import UIKit
import XCTest

@MainActor
struct HomeForumPolishTests {
    @Test
    func refreshingKeepsRowsUnchangedAndFailureStillOffersRetry() async throws {
        let route = try #require(ForumRoute("Swift开发"))
        let snapshot = try await FixtureForumHomeRepository().loadForumHome(route: route)
        var list = ForumHomeListPresentation(snapshot: snapshot, pagination: .idle)
        let original = list.rows
        list.setRetainedStatus(.refreshing)
        #expect(list.rows == original)
        list.setRetainedStatus(.refreshFailure)
        #expect(list.rows.dropFirst() == original[...])
        #expect(list.rows.first?.content == .retainedStatus(.refreshFailure))
        list.setRetainedStatus(.refreshing)
        #expect(list.rows == original)
    }

    @Test
    func removingRecentForumPersistsOnlyThatHistoryIdentity() async throws {
        let repository = InMemoryBrowsingHistoryRepository()
        try await repository.record(.forum(forumID: 8, forumName: "One", visitedAt: .distantPast))
        try await repository.record(.forum(forumID: 9, forumName: "Two", visitedAt: .distantPast))
        try await repository.record(.thread(threadID: 8, title: "Thread", forumName: "One", visitedAt: .distantPast))
        let store = BrowsingHistoryStore(repository: repository, clock: HarnessControlledClock())
        await store.loadIfNeeded()
        await store.delete(.forum(8))
        #expect(RecentForum.project(store.entries, followedForums: []).map(\.id) == [9])
        let reopened = BrowsingHistoryStore(repository: repository, clock: HarnessControlledClock())
        await reopened.loadIfNeeded()
        #expect(reopened.entries.contains { $0.identity == .thread(8) })
        #expect(!reopened.entries.contains { $0.identity == .forum(8) })
    }

    @Test
    func forumPushDoesNotAnimateAnEmptyBottomStrip() async throws {
        let root = LaunchScenarioFactory.make(scenario: .forumHomeParity).compositionRoot
        let navigation = AppNavigationStore()
        let stores = AppFeatureStoreRegistry(compositionRoot: root)
        let host = UIHostingController(rootView: AppShellView(
            navigation: navigation, harnessLabel: nil, environment: root.environment,
            featureStores: stores, sessionStore: root.sessionStore, authContextProvider: root.authContextProvider,
            notificationCounts: root.notificationCounts, onOpenLogin: {}, onOpenMedia: { _ in }
        ))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true }
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        await stores.forumHomeStore(for: .followedForums, route: route).synchronize(with: route)
        try #require(await waitFor { Self.controllers(host).contains { $0 is UINavigationController } })
        let sampler = ForumPushFrameSampler(window: window)
        defer { sampler.stop() }
        for cycle in 0..<3 {
            sampler.gaps = []
            let nav = try #require(Self.controllers(host).compactMap { $0 as? UINavigationController }.first)
            let rootHeight = nav.view.bounds.height
            sampler.start()
            navigation.push(.forum(route), in: .followedForums)
            #expect(await waitFor {
                !sampler.gaps.isEmpty && Self.controllers(host).contains {
                    guard let nav = $0 as? UINavigationController else { return false }
                    return nav.viewControllers.count > 1 && nav.transitionCoordinator == nil
                }
            })
            sampler.stop()
            #expect(abs(nav.view.bounds.height - rootHeight) <= 1, "Root selector must not resize the navigation transition container")
            print("Forum push \(cycle): frames=\(sampler.gaps.count), min=\(sampler.gaps.min() ?? -1), max=\(sampler.gaps.max() ?? -1)")
            #expect(sampler.gaps.allSatisfy { abs($0) <= 1 })
            navigation.replacePathFromSystem([], in: .followedForums)
            #expect(await waitFor {
                Self.controllers(host).compactMap { $0 as? UINavigationController }
                    .allSatisfy { $0.viewControllers.count == 1 && $0.transitionCoordinator == nil }
            })
        }
    }

    private func waitFor(_ condition: @escaping @MainActor () -> Bool) async -> Bool {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { condition() }
        }, object: nil)
        return await XCTWaiter.fulfillment(of: [ready], timeout: 5) == .completed
    }

    private static func controllers(_ root: UIViewController) -> [UIViewController] {
        [root] + root.children.flatMap(controllers)
    }
}

@MainActor
private final class ForumPushFrameSampler: NSObject {
    let window: UIWindow
    var gaps: [CGFloat] = []
    private var link: CADisplayLink?

    init(window: UIWindow) { self.window = window }

    func start() {
        stop()
        let link = CADisplayLink(target: self, selector: #selector(sample))
        self.link = link
        link.add(to: .main, forMode: .common)
    }

    func stop() { link?.invalidate(); link = nil }

    @objc private func sample() {
        for table in views(window).compactMap({ $0 as? UITableView })
            where table.accessibilityIdentifier == "forum-home.list" && !table.isHidden {
            let layer = table.layer.presentation() ?? table.layer
            let frame = layer.convert(layer.bounds, to: window.layer.presentation() ?? window.layer)
            guard frame.width > 0, frame.intersection(window.bounds).width > frame.width / 2 else { continue }
            gaps.append(window.bounds.maxY - frame.maxY)
        }
    }

    private func views(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(views) }
}
