import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

struct R05ForumMappingTests {
    @Test
    func latestAndGoodRequestsKeepAndroidSortAndClassifySemantics() throws {
        let route = try #require(ForumRoute("Fixture 吧"))
        for (query, sort, good, cid) in [
            (ForumThreadQuery.latest(.lastReply), Int32(0), Int32(0), Int32(0)),
            (.latest(.creation), 1, 0, 0), (.good(0), -1, 1, 0), (.good(12), -1, 1, 12)
        ] {
            let bytes = try FRSPageProtocol.encodeRequest(request: .init(route: route, pageNumber: 2, query: query))
            let wire = try Tieba_FrsPage_FrsPageRequest(serializedBytes: bytes).data
            #expect(wire.sortType == sort)
            #expect(wire.isGood == good)
            #expect(wire.cid == cid)
            #expect(wire.pn == 2 && wire.loadType == 2)
        }
    }

    @Test
    func navigationUsesOnlyServerOrdinaryTabsAndGoodClassIDs() throws {
        var response = Tieba_FrsPage_FrsPageResponse()
        response.data.forum.id = 101
        response.data.forum.name = "Fixture"
        response.data.forum.avatar = "https://fixture.invalid/forum.png"
        response.data.forum.userLevel = 8
        response.data.forum.isLike = 1
        response.data.forum.curScore = 12
        response.data.forum.levelupScore = 80
        var good = Tieba_FrsPage_Classify()
        good.classID = 11
        good.className = "技术资料"
        response.data.forum.goodClassify = [good]
        var tab = Tieba_FrsTabInfo()
        tab.tabID = 22
        tab.tabName = "吧友互助"
        tab.tabType = 15
        tab.isGeneralTab = 1
        var wrongKind = tab
        wrongKind.tabID = 23
        wrongKind.tabType = 99
        response.data.navTabInfo.tab = [tab, wrongKind, tab]
        response.data.forumRule.hasForumRule_p = 1
        response.data.forumRule.title = "请阅读吧规"
        let route = try #require(ForumRoute("Fixture"))
        let page = try FRSPageProtocol.map(FRSPageProtocol.decode(response.serializedData()), requestedRoute: route)
        #expect(page.forum.navigation.categories.map(\.id) == [22])
        #expect(page.forum.navigation.goodCategories == [.init(id: 11, title: "技术资料")])
        #expect(page.forum.navigation.ruleTitle == "请阅读吧规")
        #expect(page.forum.membership?.progress == 0.15)
        #expect(page.forum.levelID == 8)
    }

    @Test
    func ordinaryCategoryRequestAndResponsePreserveBusinessIDsAndRawCursor() throws {
        let route = try #require(ForumRoute(forumID: 101, forumName: "Fixture"))
        let forum = ForumSummary(forumID: 101, name: "Fixture", slogan: nil, avatarResourceID: nil,
                                 memberCount: 0, threadCount: 0, postCount: 0)
        let query = ForumThreadQuery.category(.init(id: 22, title: "吧友互助", isDefault: 0,
                                                    sorts: [.init(id: 4, title: "回复")]), sort: 4)
        let request = ForumHomePageRequest(route: route, pageNumber: 2, query: query, lastThreadID: 91, knownForum: forum)
        let wire = try Tieba_GeneralTabList_GeneralTabListRequest(serializedBytes: GeneralTabProtocol.encode(request)).data
        #expect(wire.tabID == 22 && wire.tabType == 15 && wire.isGeneralTab == 1)
        #expect(wire.tabName == "吧友互助" && wire.forumID == 101)
        #expect(wire.pn == 2 && wire.rn == 30 && wire.lastThreadID == 91 && wire.sortType == 4)
        #expect(!wire.common.hasBduss && !wire.common.hasStoken)
        let endpoint = try GeneralTabProtocol.descriptor(host: "fixture.invalid")
        #expect(endpoint.path == "/c/f/frs/generalTabList")
        var thread = Tieba_ThreadInfo()
        thread.id = 92
        thread.threadID = 192
        thread.title = "Fixture"
        thread.author.id = 302
        thread.author.portrait = "fixture-302"
        thread.lastTimeInt = 1_700_000_000
        thread.agreeNum = 7
        thread.media = (0..<8).map { index in
            var media = Tieba_Media()
            media.bigPic = "https://fixture.invalid/\(index).png"
            return media
        }
        var response = Tieba_GeneralTabList_GeneralTabListResponse()
        response.data.generalList = [thread, thread]
        response.data.hasMore_p = 1
        var bytes = try response.serializedData()
        bytes.append(contentsOf: [0xA0, 0x06, 0x01]) // Unknown field 100, tolerated by protobuf.
        let page = try GeneralTabProtocol.map(GeneralTabProtocol.decode(bytes), request: request)
        #expect(page.threads.map(\.threadID) == [192])
        #expect(page.lastThreadID == 92)
        #expect(page.threads.first?.thumbnailResources.count == 8)
        #expect(page.threads.first?.author?.avatarResource != nil)
        #expect(page.threads.first?.metadata.agreeCount == 7)
        let projection = ForumThreadRowModel(thread: try #require(page.threads.first), forumID: 101)
        #expect(projection.sourceSummary == page.threads.first)
        #expect(projection.thumbnailDescriptions.count == 3)
    }

    @Test
    func missingEmptyMalformedAndServerFailureDoNotProduceInventedCategories() throws {
        #expect(throws: FRSPageProtocolError.emptyBody) { try GeneralTabProtocol.decode(Data()) }
        #expect(throws: (any Error).self) { try GeneralTabProtocol.decode(Data([255])) }
        #expect(throws: FRSPageProtocolError.missingData) {
            try GeneralTabProtocol.decode(Data([0x0A, 0x00]))
        }
        var response = Tieba_GeneralTabList_GeneralTabListResponse()
        response.error.errorCode = 4
        #expect(throws: EndpointWireFailure.server(code: 4)) { try GeneralTabProtocol.decode(response.serializedData()) }
        var frs = Tieba_FrsPage_FrsPageResponse()
        frs.data.forum.name = "Fixture"
        let snapshot = try FRSPageProtocol.map(frs, requestedRoute: #require(ForumRoute("Fixture")))
        #expect(snapshot.forum.navigation.categories.isEmpty)
        #expect(snapshot.forum.membership == nil)
        #expect(snapshot.forum.levelID == nil)
    }
}

@MainActor
struct R05ForumTransportTests {
    @Test
    func categoryRequestRemainsAnonymousAndCancellationDoesNotBecomeAResult() async throws {
        let route = try #require(ForumRoute(forumID: 101, forumName: "Fixture"))
        let forum = ForumSummary(forumID: 101, name: "Fixture", slogan: nil, avatarResourceID: nil,
                                 memberCount: 0, threadCount: 0, postCount: 0)
        let request = ForumHomePageRequest(
            route: route, query: .category(.init(id: 22, title: "分类", isDefault: 0, sorts: []), sort: 0), knownForum: forum
        )
        let client = HarnessMockHTTPClient()
        let repository = LiveForumHomeRepository(client: client, host: "fixture.invalid")
        let task = Task { try await repository.loadForumHomePage(request) }
        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        #expect(call.request.url.path == "/c/f/frs/generalTabList")
        #expect(call.request.headers["Cookie"] == nil)
        #expect(call.request.headers["Authorization"] == nil)
        #expect(call.request.redirectPolicy == .reject)
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test
    func actualCategoryMIMEIsAcceptedWhileHTMLIsRejected() throws {
        let route = try #require(ForumRoute(forumID: 101, forumName: "Fixture"))
        let forum = ForumSummary(forumID: 101, name: "Fixture", slogan: nil, avatarResourceID: nil,
                                 memberCount: 0, threadCount: 0, postCount: 0)
        let request = ForumHomePageRequest(
            route: route, query: .category(.init(id: 22, title: "分类", isDefault: 0, sorts: []), sort: 0), knownForum: forum
        )
        var wire = Tieba_GeneralTabList_GeneralTabListResponse()
        wire.data = Tieba_GeneralTabList_GeneralTabListResponseData()
        let body = try wire.serializedData()
        let endpoint = try GeneralTabProtocol.descriptor(host: "fixture.invalid")
        let pipeline = GeneralTabProtocol.pipeline(request: request)
        let page = try pipeline.map(.init(statusCode: 200, headers: ["Content-Type": "application/protobuf"], body: body),
                                    for: endpoint)
        #expect(page.threads.isEmpty && !page.hasMore)
        #expect(throws: EndpointExecutionError.unsupportedContent(actualMIMEType: "text/html")) {
            try pipeline.map(.init(statusCode: 200, headers: ["Content-Type": "text/html"], body: body), for: endpoint)
        }
        #expect(!FRSPageProtocol.allowedResponseMIMETypes.contains("application/protobuf"))
    }

    @Test
    func categoryTimeoutRetainsTypedFailureAndDoesNotRetry() async throws {
        let route = try #require(ForumRoute(forumID: 101, forumName: "Fixture"))
        let forum = ForumSummary(forumID: 101, name: "Fixture", slogan: nil, avatarResourceID: nil,
                                 memberCount: 0, threadCount: 0, postCount: 0)
        let request = ForumHomePageRequest(
            route: route, query: .category(.init(id: 22, title: "分类", isDefault: 0, sorts: []), sort: 0), knownForum: forum
        )
        let client = HarnessMockHTTPClient(defaultBehavior: .failure(.timedOut))
        let repository = LiveForumHomeRepository(client: client, host: "fixture.invalid")
        await #expect(throws: EndpointExecutionError.transport(.timedOut)) { try await repository.loadForumHomePage(request) }
        let started = await client.events().filter { if case .started = $0 { true } else { false } }
        #expect(started.count == 1)
    }
}
