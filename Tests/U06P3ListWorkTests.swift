import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct U06P3ListWorkTests {
    @Test(arguments: [1, 3, 5])
    func cachedPagesMergeOnceWithOriginalOrderAndMetadata(pageCount: Int) throws {
        let forum = ForumSummary(forumID: 13_001, name: "Fixture", slogan: nil, avatarResourceID: nil,
                                 memberCount: 0, threadCount: 1_000, postCount: 0)
        let pages = (0..<pageCount).map { page in
            ForumCachedPage(requestPage: page + 1, requestCursor: Int64(page * 200), fetchedAt: .distantPast,
                            page: ForumPageDTO(ForumHomeSnapshot(forum: forum, threads: (0..<200).map { row in
                let id = Int64(page * 199 + row + 1)
                return ForumThreadSummary(itemID: id, threadID: id, title: "page-\(page)", forumName: "Fixture",
                                          authorName: "Fixture", replyCount: 0, viewCount: 0, isPinned: row == 0)
            }, currentPage: page + 1, hasMore: page != pageCount - 1, lastThreadID: Int64((page + 1) * 200))))
        }
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Fixture"))
        let reading = ForumCachedReading(generation: "fixture", queryIdentity: .init(route: route, query: .latest(.creation)),
                                         context: .anonymous, cacheEpoch: 0, pages: pages, anchor: 430, isFresh: true)
        let original = pages.dropFirst().reduce(pages[0].page.snapshot) { $0.appending($1.page.snapshot) }
        #expect(reading.assembly.snapshot == original)
        #expect(reading.assembly.visitedItems == pageCount * 200)
        #expect(reading.anchor == 430)
    }

    @Test func repeatedPrefetchPreparesIDsOnlyOnce() async throws {
        let source = P3PrefetchSource()
        let session = ContentPrefetchSession(candidates: .init(allowed: { true }), nextPage: .init(allowed: { true }),
                                             threads: source, forums: nil, sort: { _ in .creation })
        let repository = Stage15LongThreadFixtureRepository(threadID: 990_015, totalPostCount: 1_000, pageSize: 200)
        let store = ThreadReaderStore(threadID: 990_015, repository: repository, prefetch: session)
        await store.loadIfNeeded()
        let firstRows = store.configuredRows(textSize: .standard)
        let initialRevision = store.listRevision
        for _ in 0..<30 { store.prefetchNextPage() }
        try await source.started.wait()
        #expect(store.prefetchPreparationCount == 1)
        #expect(await source.requests == 1)
        for row in firstRows.prefix(30) {
            store.setReadAnchor(row.id)
            #expect(store.configuredRows(textSize: .standard) == firstRows)
        }
        #expect(store.configuredRowsBuildCount == 1 && store.listRevision == initialRevision)
        #expect(store.configuredRows(textSize: .large).allSatisfy { $0.readingTextSize == .large })
        #expect(store.configuredRowsBuildCount == 2)
        await store.loadNextPage()
        #expect(store.state.snapshot?.posts.count == 400)
        #expect(store.configuredRows(textSize: .large).count == 401)
        #expect(store.listRevision > initialRevision)
        store.cancel()
    }

    @Test func anchorAndCallbackUpdatesDoNotPrepareAllThousandRows() async throws {
        let list = makeList()
        let table = VirtualizedTableView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), style: .plain)
        let coordinator = list.makeCoordinator()
        coordinator.install(on: table)
        coordinator.synchronize()
        for _ in 0..<1_000 where coordinator.isApplyingSnapshot { await Task.yield() }
        #expect(!coordinator.isApplyingSnapshot)
        let before = table.virtualListDiagnostics
        for index in 0..<30 {
            coordinator.parent = makeList(anchor: index)
            coordinator.synchronize()
        }
        #expect(table.virtualListDiagnostics.preparationCount == before.preparationCount)
        #expect(table.virtualListDiagnostics.snapshotApplyCount == before.snapshotApplyCount)
        coordinator.dismantle()
    }

    @Test func queuedVersionsPublishLatestContentFooterAndCurrentCallbacks() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let controller = UIViewController()
        window.rootViewController = controller
        let table = VirtualizedTableView(frame: window.bounds, style: .plain)
        controller.view.addSubview(table)
        window.makeKeyAndVisible()
        var action = 0
        func list(_ revision: Int, count: Int = 30, callback: Int = 0, fontSize: Double = 14) -> VirtualizedList<P3Row, P3ActionRow> {
            VirtualizedList(items: (0..<count).map { .init(id: $0, text: "version-\(revision)") },
                            backgroundColor: .systemBackground, accessibilityIdentifier: "p3.queue",
                            contentVersion: "\(revision):\(fontSize)", rowContent: { row in
                P3ActionRow(title: row.text, fontSize: fontSize, action: { action = callback })
            })
        }
        let coordinator = list(1).makeCoordinator()
        defer { coordinator.dismantle(); window.isHidden = true }
        coordinator.install(on: table)
        coordinator.synchronize()
        #expect(coordinator.isApplyingSnapshot)
        coordinator.parent = list(2, count: 31)
        coordinator.synchronize()
        coordinator.parent = list(3, count: 32)
        coordinator.synchronize()
        #expect(coordinator.completedVersion == nil)
        for _ in 0..<1_000 where coordinator.isApplyingSnapshot { await Task.yield() }
        #expect(coordinator.dataSource?.snapshot().itemIdentifiers.count == 32)
        #expect(coordinator.appliedItemsByID[0]?.text == "version-3")
        #expect(coordinator.completedVersion?.content == AnyHashable("3:14.0"))
        table.layoutIfNeeded()
        let before = table.virtualListDiagnostics
        coordinator.parent = list(3, count: 32, callback: 99)
        coordinator.synchronize()
        for _ in 0..<100 {
            table.layoutIfNeeded()
            await Task.yield()
        }
        let button = try #require(findButton(in: table))
        button.sendActions(for: .touchUpInside)
        #expect(action == 99)
        #expect(table.virtualListDiagnostics.preparationCount == before.preparationCount)
        #expect(table.virtualListDiagnostics.snapshotApplyCount == before.snapshotApplyCount)
        coordinator.parent = list(3, count: 32, fontSize: 26)
        coordinator.synchronize()
        for _ in 0..<100 where findButton(in: table)?.titleLabel?.font.pointSize != 26 {
            table.layoutIfNeeded()
            await Task.yield()
        }
        #expect(findButton(in: table)?.titleLabel?.font.pointSize == 26)
        // A replacement owner/query uses a new token even when IDs and counts overlap.
        coordinator.parent = list(4, count: 2)
        coordinator.synchronize()
        for _ in 0..<1_000 where coordinator.isApplyingSnapshot { await Task.yield() }
        #expect(coordinator.appliedItemsByID.count == 2)
        #expect(coordinator.appliedItemsByID[0]?.text == "version-4")
    }

    private func findButton(in view: UIView) -> UIButton? {
        if let button = view as? UIButton { return button }
        return view.subviews.lazy.compactMap { findButton(in: $0) }.first
    }

    private func makeList(anchor: Int? = nil) -> VirtualizedList<P3Row, Text> {
        VirtualizedList(items: (0..<1_000).map { P3Row(id: $0, text: "row-\($0)") },
                        backgroundColor: .systemBackground, accessibilityIdentifier: "p3.list",
                        restoredAnchor: anchor, contentVersion: "fixture-1", rowContent: { Text($0.text) })
    }
}

private struct P3Row: Identifiable, Equatable, Sendable { let id: Int; let text: String }

private struct P3ActionRow: UIViewRepresentable {
    let title: String
    let fontSize: Double
    let action: () -> Void
    func makeUIView(context: Context) -> UIButton { UIButton(type: .system) }
    func updateUIView(_ button: UIButton, context: Context) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: fontSize)
        button.removeAction(identifiedBy: .init("p3.action"), for: .touchUpInside)
        button.addAction(UIAction(identifier: .init("p3.action")) { _ in action() }, for: .touchUpInside)
    }
}

private actor P3PrefetchSource: ThreadContentPrefetching {
    private(set) var requests = 0
    nonisolated let started = HarnessContinuationGate<Void>()
    func prefetchThread(_ request: ThreadReaderPageRequest) async throws {
        requests += 1
        started.succeed(())
        throw CancellationError()
    }
}
