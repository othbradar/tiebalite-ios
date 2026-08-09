import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct Stage14PForumHomePerformanceTests {
    @Test
    func rowPresentationUsesThreadIDAndPrecomputesKinds() throws {
        let snapshot = ForumHomeSnapshot(
            forum: makeForum(),
            threads: [
                makeThread(
                    itemID: 1,
                    threadID: 101,
                    isPinned: true
                ),
                makeThread(
                    itemID: 2,
                    threadID: 102,
                    mediaCount: 1
                ),
                makeThread(
                    itemID: 3,
                    threadID: 103,
                    mediaCount: 4
                ),
                makeThread(
                    itemID: 4,
                    threadID: 104,
                    hasVideo: true
                ),
                makeThread(
                    itemID: 999,
                    threadID: 102,
                    title: "迟到重复项"
                )
            ],
            currentPage: 1,
            hasMore: true
        )

        let presentation = ForumHomeListPresentation(
            snapshot: snapshot,
            pagination: .idle
        )
        let rows = presentation.threadRows

        #expect(rows.map(\.threadID) == [101, 102, 103, 104])
        #expect(rows.map(\.rowKind) == [
            .top,
            .singleMedia,
            .multiMedia,
            .video
        ])
        #expect(rows[1].thumbnailDescriptions.count == 1)
        #expect(rows[2].thumbnailDescriptions.count == 3)
        #expect(rows[2].additionalThumbnailCount == 1)
        #expect(
            presentation.rows.filter {
                if case .thread = $0.id {
                    return true
                }
                return false
            }.map(\.id) == [
                .thread(101),
                .thread(102),
                .thread(103),
                .thread(104)
            ]
        )
    }

    @Test
    func tenFixturePagesAppendOneThousandThreadsWithoutDuplicates() async throws {
        let repository = DebugStage14PLongForumFixtureRepository()
        let route = try #require(ForumRoute("Stage14P性能"))
        let store = ForumHomeStore(route: route, repository: repository)

        await store.synchronize(with: route)
        let firstRows = try #require(store.listPresentation?.threadRows)
        #expect(firstRows.count == 100)

        for expectedPage in 2...10 {
            await store.loadNextPage()
            let rows = try #require(store.listPresentation?.threadRows)
            #expect(rows.count == expectedPage * 100)
            #expect(rows.prefix(100).elementsEqual(firstRows))
            #expect(Set(rows.map(\.threadID)).count == rows.count)
        }

        #expect(store.state.snapshot?.threads.count == 1_000)
        #expect(store.state.snapshot?.hasMore == false)
        #expect(await repository.requestedPageNumbers() == Array(1...10))

        await store.loadNextPage()
        #expect(await repository.requestedPageNumbers() == Array(1...10))
    }

    @Test
    func crossPageDuplicatesKeepTheFirstThreadAndServerOrder() throws {
        let first = ForumHomeSnapshot(
            forum: makeForum(),
            threads: [
                makeThread(itemID: 1, threadID: 101, isPinned: true),
                makeThread(itemID: 2, threadID: 102)
            ],
            currentPage: 1,
            hasMore: true
        )
        let second = ForumHomeSnapshot(
            forum: makeForum(),
            threads: [
                makeThread(
                    itemID: 999,
                    threadID: 101,
                    title: "迟到的重复置顶帖",
                    isPinned: true
                ),
                makeThread(itemID: 3, threadID: 103),
                makeThread(itemID: 4, threadID: 104)
            ],
            currentPage: 2,
            hasMore: false
        )

        let aggregate = first.appending(second)
        var presentation = ForumHomeListPresentation(
            snapshot: first,
            pagination: .idle
        )
        presentation.append(
            threads: second.threads,
            pagination: .end
        )

        #expect(aggregate.threads.map(\.threadID) == [101, 102, 103, 104])
        #expect(aggregate.threads.first?.itemID == 1)
        #expect(presentation.threadRows.map(\.threadID) == [101, 102, 103, 104])
        #expect(presentation.threadRows.first?.itemID == 1)
        #expect(presentation.pagination == .end)
    }

    @Test
    func nextPageFailureRetainsRowsAndRetryRequestsTheSamePage() async throws {
        let repository = DebugStage14PLongForumFixtureRepository(
            totalThreadCount: 300,
            failOnceOnPage: 3
        )
        let route = try #require(ForumRoute("Stage14P重试"))
        let store = ForumHomeStore(route: route, repository: repository)

        await store.synchronize(with: route)
        await store.loadNextPage()
        let retained = try #require(store.listPresentation?.threadRows)
        #expect(retained.count == 200)

        await store.loadNextPage()
        #expect(store.state.snapshot?.threads.count == 200)
        #expect(store.listPresentation?.pagination == .failure)

        await store.loadNextPage()
        #expect(store.state.snapshot?.threads.count == 300)
        #expect(store.listPresentation?.pagination == .end)
        #expect(await repository.requestedPageNumbers() == [1, 2, 3, 3])
    }

    @Test
    func concurrentPrefetchRequestsShareOneInFlightPage() async throws {
        let route = try #require(ForumRoute("Stage14P并发"))
        let repository = Stage14PControlledPageRepository(
            initial: ForumHomeSnapshot(
                forum: makeForum(),
                threads: [makeThread(itemID: 1, threadID: 101)],
                currentPage: 1,
                hasMore: true
            )
        )
        let store = ForumHomeStore(route: route, repository: repository)
        await store.synchronize(with: route)

        let first = Task { await store.loadNextPage() }
        try await repository.waitForPageTwo()
        let second = Task { await store.loadNextPage() }
        await Task.yield()

        #expect(await repository.requestedPageNumbers() == [1, 2])
        try await repository.finishPageTwo(
            ForumHomeSnapshot(
                forum: makeForum(),
                threads: [makeThread(itemID: 2, threadID: 102)],
                currentPage: 2,
                hasMore: false
            )
        )
        await first.value
        await second.value
        #expect(store.state.snapshot?.threads.map(\.threadID) == [101, 102])
    }

    @Test
    func forumTableVirtualizesOneThousandRowsWithBoundedCells() async throws {
        let repository = DebugStage14PLongForumFixtureRepository()
        let route = try #require(ForumRoute("Stage14P表格"))
        var pages: [ForumHomeSnapshot] = []
        for page in 1...10 {
            pages.append(
                try await repository.loadForumHomePage(
                    ForumHomePageRequest(route: route, pageNumber: page)
                )
            )
        }
        var aggregate = try #require(pages.first)
        var presentation = ForumHomeListPresentation(
            snapshot: aggregate,
            pagination: .idle
        )

        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        var list = makeList(presentation)
        let coordinator = list.makeCoordinator()
        let table = VirtualizedTableView(
            frame: window.bounds,
            style: .plain
        )
        window.addSubview(table)
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        window.layoutIfNeeded()
        table.layoutIfNeeded()
        await waitForItems(presentation.rows.count, coordinator: coordinator)

        for page in pages.dropFirst() {
            let previousCount = aggregate.threads.count
            aggregate = aggregate.appending(page)
            presentation.append(
                threads: Array(aggregate.threads.dropFirst(previousCount)),
                pagination: aggregate.hasMore ? .idle : .end
            )
            list = makeList(presentation)
            coordinator.parent = list
            coordinator.synchronize()
            await waitForItems(presentation.rows.count, coordinator: coordinator)
        }

        for threadID in [990_999, 990_499, 990_000] {
            let rowID = ForumHomeRowID.thread(Int64(threadID))
            let indexPath = try #require(coordinator.dataSource?.indexPath(for: rowID))
            table.scrollToRow(at: indexPath, at: .middle, animated: false)
            table.layoutIfNeeded()
            await Task.yield()
            #expect(table.indexPathsForVisibleRows?.contains(indexPath) == true)
        }

        let diagnostics = table.virtualListDiagnostics
        #expect(diagnostics.itemCount == presentation.rows.count)
        #expect(diagnostics.reuseCount > 0)
        #expect(diagnostics.peakVisibleCellCount > 0)
        #expect(
            diagnostics.createdCellCount
                <= diagnostics.peakVisibleCellCount * 4
        )
        #expect(
            diagnostics.activeHostedCellCount
                <= diagnostics.peakActiveHostedCellCount
        )

        coordinator.dismantle()
        table.removeFromSuperview()
        #expect(table.virtualListDiagnostics.activeHostedCellCount == 0)
    }

    private func makeList(
        _ presentation: ForumHomeListPresentation
    ) -> VirtualizedList<ForumHomeRowModel, ForumHomeRowView> {
        VirtualizedList(
            items: presentation.rows,
            backgroundColor: .systemBackground,
            accessibilityIdentifier: "stage14p.virtual-list",
            rowContent: { row in
                ForumHomeRowView(
                    row: row,
                    onOpenThread: { _ in },
                    requestReload: {},
                    requestNextPage: {}
                )
            }
        )
    }

    private func waitForItems(
        _ expectedCount: Int,
        coordinator: VirtualizedList<
            ForumHomeRowModel,
            ForumHomeRowView
        >.Coordinator
    ) async {
        for _ in 0..<100 {
            if coordinator.dataSource?.snapshot().numberOfItems
                == expectedCount {
                return
            }
            await Task.yield()
        }
    }

    private func makeForum() -> ForumSummary {
        ForumSummary(
            forumID: 14_000,
            name: "Stage14P",
            slogan: "长列表性能 Fixture",
            avatarResourceID: nil,
            memberCount: 1_000,
            threadCount: 1_000,
            postCount: 10_000
        )
    }

    private func makeThread(
        itemID: Int64,
        threadID: Int64,
        title: String = "Fixture 帖子",
        isPinned: Bool = false,
        mediaCount: Int = 0,
        hasVideo: Bool = false
    ) -> ForumThreadSummary {
        ForumThreadSummary(
            itemID: itemID,
            threadID: threadID,
            title: title,
            summary: "这是预计算好的摘要。",
            forumName: "Stage14P",
            authorName: "Fixture 作者",
            replyCount: 2,
            viewCount: 3,
            isPinned: isPinned,
            mediaCount: mediaCount,
            hasVideo: hasVideo
        )
    }
}

private actor Stage14PControlledPageRepository: ForumHomeRepository {
    private let initial: ForumHomeSnapshot
    private let pageTwoGate = HarnessContinuationGate<ForumHomeSnapshot>()
    private let pageTwoObserved = HarnessContinuationGate<Void>()
    private var requestedPages: [Int] = []

    init(initial: ForumHomeSnapshot) {
        self.initial = initial
    }

    func loadForumHomePage(
        _ request: ForumHomePageRequest
    ) async throws -> ForumHomeSnapshot {
        requestedPages.append(request.pageNumber)
        switch request.pageNumber {
        case 1:
            return initial
        case 2:
            pageTwoObserved.succeed(())
            return try await pageTwoGate.wait()
        default:
            throw FixtureReadingRepositoryError.unavailable
        }
    }

    func waitForPageTwo() async throws {
        if requestedPages.contains(2) {
            return
        }
        try await pageTwoObserved.wait()
    }

    func finishPageTwo(_ snapshot: ForumHomeSnapshot) throws {
        guard pageTwoGate.succeed(snapshot) else {
            throw FixtureReadingRepositoryError.unavailable
        }
    }

    func requestedPageNumbers() -> [Int] {
        requestedPages
    }
}
