import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

struct R11NotificationTargetTests {
    @MainActor @Test func themeQuoteCanOpenThreadInMessagesWithoutAReplyAnchor() throws {
        let navigation = AppNavigationStore()
        let threadID = try #require(ThreadID(8_001))
        navigation.selectTab(.notifications)
        #expect(navigation.push(.thread(threadID), in: .notifications))
        #expect(navigation.state.routes(for: .notifications) == [.thread(threadID)])
        let postID = try #require(PostID(9_002))
        let otherThread = try #require(ThreadID(8_002))
        #expect(RouteGrammar.isValid([.thread(threadID), .subposts(threadID: threadID, postID: postID)], for: .notifications))
        #expect(!RouteGrammar.isValid([.thread(threadID), .subposts(threadID: otherThread, postID: postID)], for: .notifications))
    }

    @Test func subpostSelectorResolvesParentWithoutTrustingQuoteID() throws {
        let target = NotificationTarget(threadID: 8_001, postID: 10_001, isSubpost: true)
        guard case let .multipartBinary(_, fields, part) = try LiveNotificationTargetRepository.subpostBody(target) else {
            Issue.record("Expected existing multipart encoder")
            return
        }
        let request = try Tieba_PbFloor_PbFloorRequest(serializedBytes: part.data)
        #expect(fields.isEmpty && request.data.pid == 0 && request.data.spid == 10_001)
        #expect(!request.data.common.hasBduss && !request.data.common.hasStoken)
        let wire = try PBFloorProtocol.decode(R08PBFloorFixture.bytes(page: 1))
        let page = try LiveNotificationTargetRepository.mapSubpost(wire, target: target)
        #expect(page.route.postID == 9_002 && page.items.contains { $0.id == 10_001 })
        #expect(throws: (any Error).self) {
            try LiveNotificationTargetRepository.mapSubpost(wire, target: .init(threadID: 8_001, postID: 999_999, isSubpost: true))
        }
    }

    @Test func endpointIsHTTPSAuthenticatedAndDoesNotFabricateDeviceFields() throws {
        for kind in [NotificationKind.replies, .mentions] {
            let endpoint = try NotificationsProtocol.descriptor(kind: kind)
            #expect(endpoint.path == kind.path && endpoint.authentication == .active && endpoint.retryPolicy == .never)
            #expect(endpoint.fixedHeaders["Cookie"] == "ka=open")
            guard case let .formURLEncoded(fields) = try NotificationsProtocol.body(
                kind: kind, page: 2, authorization: .init(bduss: "fixture-bduss", stoken: "fixture-stoken")) else {
                Issue.record("Expected form body"); return
            }
            let values = Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.value) })
            #expect(values["pn"] == "2" && values["_client_version"] == "8.2.2" && values["sign"]?.count == 32)
            #expect(values["BDUSS"] == "fixture-bduss" && values["cuid"] == nil && values["stTime"] == nil)
        }
    }

    @MainActor @Test func messageOpensCompleteThreadAndScrollsToParentOrReply() async throws {
        let store = NotificationDestinationStore(
            target: .init(threadID: 8_001, postID: 10_001, isSubpost: true),
            repository: FixtureNotificationTargetRepository(),
            threads: FixtureThreadReaderRepository())
        await store.load()
        #expect(store.thread?.readAnchor == .post(threadID: 8_001, postID: 9_002))
        #expect(store.thread?.state.snapshot?.posts.first?.floorNumber == 1)
        let thread = NotificationDestinationStore(
            target: .init(threadID: 8_001, postID: 9_001, isSubpost: false),
            repository: FixtureNotificationTargetRepository(),
            threads: FixtureThreadReaderRepository())
        await thread.load()
        #expect(thread.thread?.readAnchor == .post(threadID: 8_001, postID: 9_001))
        #expect(thread.thread?.state.snapshot?.posts.first?.floorNumber == 1)
        await thread.thread?.loadIfNeeded()
        #expect(thread.thread?.state.snapshot?.posts.first?.floorNumber == 1)
    }
    @MainActor @Test func laterReplyKeepsEarlierPagesAndDoesNotReloadOnDisplay() async throws {
        let repository = Stage17ControlledThreadRepository()
        let store = NotificationDestinationStore(target: .init(threadID: 8_001, postID: 9_018, isSubpost: false),
                                                 repository: FixtureNotificationTargetRepository(), threads: repository)
        let loading = Task { await store.load() }
        try await repository.waitForCallCount(1)
        try await repository.succeedLatest()
        try await repository.waitForCallCount(2)
        #expect(store.thread == nil)
        try await repository.succeedLatest()
        await loading.value
        let reader = try #require(store.thread)
        #expect(reader.readAnchor == .post(threadID: 8_001, postID: 9_018))
        #expect(reader.state.snapshot?.posts.map(\.floorNumber) == Array(1...28))
        #expect(reader.state.snapshot?.hasMore == true)
        await reader.loadIfNeeded()
        await store.load()
        #expect(await repository.callCount() == 2)
    }

    @MainActor @Test func cancelWhileFindingLaterReplyDoesNotPublishPartialThread() async throws {
        let repository = Stage17ControlledThreadRepository()
        let store = NotificationDestinationStore(target: .init(threadID: 8_001, postID: 9_018, isSubpost: false),
                                                 repository: FixtureNotificationTargetRepository(), threads: repository)
        let loading = Task { await store.load() }
        try await repository.waitForCallCount(1)
        try await repository.succeedLatest()
        try await repository.waitForCallCount(2)
        store.cancel()
        await loading.value
        #expect(store.thread == nil && !store.failed)
        #expect(await repository.callCount() == 2)
    }

    @MainActor @Test func stalledPaginationShowsFailureInsteadOfOpeningTheWrongFloor() async {
        let repository = Stage156NoProgressThreadRepository()
        let store = NotificationDestinationStore(target: .init(threadID: 8_001, postID: 9_018, isSubpost: false),
                                                 repository: FixtureNotificationTargetRepository(), threads: repository)
        await store.load()
        #expect(store.thread == nil && store.failed)
        #expect(await repository.requests().count == 2)
    }

    @MainActor @Test func replyAnchorWaitsForVisibleViewportAndIsConsumedOnlyOnce() async {
        func list(_ count: Int) -> VirtualizedList<R11AnchorItem, some View> {
            VirtualizedList(items: (1...count).map(R11AnchorItem.init), backgroundColor: .systemBackground,
                            accessibilityIdentifier: "r11.anchor", restoredAnchor: 21) { item in
                Text("楼层 \(item.id)").frame(height: 80)
            }
        }
        let initial = list(40)
        let coordinator = initial.makeCoordinator()
        let table = VirtualizedTableView(frame: .zero, style: .plain)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 180
        coordinator.install(on: table)
        coordinator.synchronize()
        while coordinator.isApplyingSnapshot { await Task.yield() }
        #expect(table.contentOffset == .zero)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        table.frame = window.bounds
        window.addSubview(table)
        window.makeKeyAndVisible()
        table.layoutIfNeeded()
        #expect(table.indexPathsForVisibleRows?.first?.row == 20)
        table.setContentOffset(.zero, animated: false)
        coordinator.parent = list(45)
        coordinator.synchronize()
        while coordinator.isApplyingSnapshot { await Task.yield() }
        table.layoutIfNeeded()
        #expect(table.contentOffset == .zero)
        table.frame.size = CGSize(width: 600, height: 390)
        table.layoutIfNeeded()
        #expect(table.contentOffset == .zero)
        coordinator.dismantle()
        window.isHidden = true
    }

}

private struct R11AnchorItem: Identifiable, Equatable, Sendable {
    let id: Int
}
