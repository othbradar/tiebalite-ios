import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct R11NotificationsStoreTests {
    private let context = AuthContext.active(.init(sessionID: .init(rawValue: 1), generation: 1))

    @Test func twoTabsKeepSeparatePagesDeduplicateAndIgnoreFooterAnchor() async throws {
        let store = NotificationsStore(repository: FixtureNotificationsRepository())
        store.updateContext(context)
        await store.loadSelected()
        #expect(store.replies.items.count == 15 && store.mentions.phase == .idle)
        #expect(store.unreadCount == 3)
        let anchor = try #require(store.replies.items.last?.id)
        store.replies.setAnchor(anchor)
        store.replies.setAnchor("replies.footer")
        await store.replies.loadNextPage()
        #expect(store.replies.items.count == 29 && store.replies.nextPage == nil)
        #expect(Set(store.replies.items.map(\.id)).count == 29)
        #expect(store.replies.readAnchor == anchor)
        store.select(.mentions)
        await store.loadSelected()
        #expect(store.mentions.items.count == 15 && store.replies.items.count == 29)
        #expect(store.replies.readAnchor == anchor)
        #expect(store.replies.rows.last?.id == "replies.footer")
    }

    @Test func refreshAndPaginationFailureRetainMessagesAndRetrySamePage() async throws {
        let repository = R11ControlledNotificationsRepository()
        let store = NotificationsStore(repository: repository)
        store.updateContext(context)
        await store.replies.loadIfNeeded()
        let old = store.replies.items
        await repository.setFailure(.transport(.timedOut))
        await store.replies.loadNextPage()
        #expect(store.replies.phase == .nextPageFailure && store.replies.items == old && store.replies.nextPage == 2)
        await store.replies.refresh()
        #expect(store.replies.phase == .refreshFailure && store.replies.items == old)
        await repository.setFailure(nil)
        await store.replies.loadNextPage()
        #expect(store.replies.items.count == 29)
        let calls = await repository.pages
        #expect(calls == [0, 2, 0, 2])
    }

    @Test func duplicatePaginationAndLateResponseCannotLeakAcrossSession() async throws {
        let repository = R11ControlledNotificationsRepository()
        let store = NotificationsStore(repository: repository)
        store.updateContext(context)
        await store.replies.loadIfNeeded()
        await repository.holdNext()
        let loading = Task { await store.replies.loadNextPage() }
        await repository.waitForHeldRequest()
        #expect(store.replies.phase == .loadingNextPage)
        await store.replies.loadNextPage()
        #expect(await repository.pages == [0, 2])
        store.updateContext(.anonymous)
        await repository.release()
        await loading.value
        #expect(store.replies.items.isEmpty && store.replies.phase == .idle && store.unreadCount == 0)
        store.updateContext(.active(.init(sessionID: .init(rawValue: 2), generation: 2)))
        await store.replies.loadIfNeeded()
        #expect(store.replies.items.count == 15)
    }

    @Test func initialFailureEmptyAndCancellationHaveDistinctStates() async {
        let repository = R11ControlledNotificationsRepository()
        let store = NotificationsStore(repository: repository)
        store.updateContext(context)
        await repository.setFailure(.decode)
        await store.replies.loadIfNeeded()
        #expect(store.replies.phase == .initialFailure && store.replies.error == .decode)
        await repository.setFailure(nil)
        await repository.setEmpty()
        await store.replies.refresh()
        #expect(store.replies.phase == .empty && store.replies.nextPage == nil)
        await repository.holdNext()
        let refresh = Task { await store.replies.refresh() }
        await repository.waitForHeldRequest()
        store.replies.cancel()
        await repository.release()
        await refresh.value
        #expect(store.replies.phase == .empty)
    }

    @Test func unreadUsesOnlySuccessfulServerCountsAndSessionClearsPrivateState() async {
        let repository = R11ControlledNotificationsRepository()
        let store = NotificationsStore(repository: repository)
        store.updateContext(context)
        await store.refreshCounts()
        #expect(store.unreadCount == 3)
        store.select(.mentions)
        #expect(store.unreadCount == 3)
        await repository.setCounts(.init(replies: 2, mentions: 0))
        await store.loadSelected()
        #expect(store.unreadCount == 2)
        await repository.setFailure(.transport(.offline))
        await store.refreshCounts()
        #expect(store.unreadCount == 2 && store.countFailure == .transport(.offline))
        store.updateContext(.anonymous)
        #expect(store.unreadCount == 0 && store.mentions.items.isEmpty)
    }

    @Test func readCompletionWaitsForOlderCountThenFetchesAgain() async throws {
        let repository = R11ControlledNotificationsRepository()
        let store = NotificationsStore(repository: repository)
        store.updateContext(context)
        await repository.holdNextCount()
        let old = Task { await store.refreshCounts() }
        await repository.waitForHeldRequest()
        await repository.setCounts(.zero)
        let read = Task { await store.loadSelected() }
        await repository.release()
        await old.value
        await read.value
        #expect(store.unreadCount == 0)
        #expect(await repository.countCalls == 2)
    }

    @Test func notificationRoutesKeepOtherStacksAndHideBottomBarOnlyInDestination() throws {
        let navigation = AppNavigationStore()
        let target = NotificationTarget(threadID: 8_001, postID: 9_001, isSubpost: false)
        navigation.selectTab(.notifications)
        #expect(AppShellPresentation.showsPhoneTabSelector(in: navigation.state))
        #expect(navigation.push(.notification(target), in: .notifications))
        #expect(!AppShellPresentation.showsPhoneTabSelector(in: navigation.state))
        #expect(navigation.push(.thread(try #require(ThreadID(8_002))), in: .recommendations))
        for tab in AppTab.allCases { navigation.selectTab(tab) }
        #expect(navigation.state.routes(for: .notifications) == [.notification(target)])
        #expect(!navigation.push(.thread(try #require(ThreadID(8_003))), in: .notifications))
    }
}

private actor R11ControlledNotificationsRepository: NotificationsRepository {
    var pages: [Int] = []
    var failure: EndpointExecutionError?
    var empty = false
    var counts = NotificationCounts(replies: 2, mentions: 1)
    var holdCount = false
    var countCalls = 0
    var shouldHold = false
    var held: CheckedContinuation<Void, Never>?
    var waiting: CheckedContinuation<Void, Never>?

    func setFailure(_ value: EndpointExecutionError?) { failure = value }
    func setCounts(_ value: NotificationCounts) { counts = value }
    func setEmpty() { empty = true }
    func holdNextCount() { holdCount = true }
    func holdNext() { shouldHold = true }
    func waitForHeldRequest() async {
        if held != nil { return }
        await withCheckedContinuation { waiting = $0 }
    }
    func release() { held?.resume(); held = nil }
    func load(kind: NotificationKind, page: Int, context: AuthContext) async throws -> NotificationPage {
        pages.append(page)
        if shouldHold {
            shouldHold = false
            await withCheckedContinuation { held = $0; waiting?.resume(); waiting = nil }
        }
        if let failure { throw failure }
        if empty { return .init(items: [], nextPage: nil) }
        return try NotificationsProtocol.decodePage(R11NotificationFixture.bytes(kind: kind, page: page), kind: kind, page: page)
    }
    func unread(context: AuthContext) async throws -> NotificationCounts {
        countCalls += 1
        let retained = counts
        if holdCount {
            holdCount = false
            await withCheckedContinuation { held = $0; waiting?.resume(); waiting = nil }
        }
        if let failure { throw failure }
        return retained
    }
}
