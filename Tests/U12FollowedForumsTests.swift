import Foundation
import Testing
@testable import TiebaLite

struct U12FollowedForumsTests {
    @Test func successfulResponseWithoutListIsUnavailableRatherThanMalformed() throws {
        for _ in 0..<3 {
            #expect(throws: ProfileContentFailure.contentUnavailable) {
                try NativeProfileProtocol.forums(ForumAvailabilityFixture.unavailable, cursor: nil)
            }
        }
    }

    @MainActor @Test(arguments: ["refresh", "next", "cached"])
    func unavailableContentReplacesOldRowsWithoutRetryOrEmptyCache(_ entry: String) async throws {
        let scope = ContentCacheContext(namespace: "fixture-a", revision: 1)
        let wire = ForumAvailabilityFixture()
        let repository = CachedProfileContentRepository(cache: ContentPageCache(directory: nil), scheduler: ContentLoadScheduler(),
                                                        context: { scope }, execute: { _, _ in try await wire.read() })
        let route = ProfileListRoute(user: try #require(UserProfileRoute(userID: 42, fallbackDisplayName: "Fixture")), section: .forums)
        let store = ProfileListStore(route: route, repository: repository, context: { scope })
        if entry == "cached" {
            _ = try await repository.load(route, cursor: nil, scope: scope)
        } else {
            await store.activate()
            #expect(store.forums.map(\.id) == [13_001])
            store.setAnchor(.forum(13_001))
        }
        #expect(await repository.cached(route, scope: scope) != nil)
        await wire.set(ForumAvailabilityFixture.unavailable)
        switch entry {
        case "cached": await store.activate()
        case "next": await store.loadMore()
        default: await store.refresh()
        }
        #expect(store.state == .contentUnavailable)
        #expect(store.forums.isEmpty && store.rows.isEmpty && store.next == nil && store.anchor == nil)
        #expect(await repository.cached(route, scope: scope) == nil)
        await store.activate()
        await store.loadMore()
        #expect(await wire.reads == 2)
        await wire.set(ForumAvailabilityFixture.visible)
        await store.refresh()
        #expect(store.state == .loaded && store.forums.map(\.id) == [13_001])
    }

    @MainActor @Test(arguments: ["malformed", "server", "network"])
    func actualErrorsStillOfferRetry(_ failure: String) async throws {
        let scope = ContentCacheContext(namespace: "fixture-a", revision: 1)
        let wire = ForumAvailabilityFixture()
        await wire.fail(failure)
        let repository = CachedProfileContentRepository(cache: ContentPageCache(directory: nil), scheduler: ContentLoadScheduler(),
                                                        context: { scope }, execute: { _, _ in try await wire.read() })
        let route = ProfileListRoute(user: try #require(UserProfileRoute(userID: 42, fallbackDisplayName: "Fixture")), section: .forums)
        let store = ProfileListStore(route: route, repository: repository, context: { scope })
        await store.activate()
        #expect(store.state == .failed)
        #expect(await repository.cached(route, scope: scope) == nil)
        #expect(await wire.reads == 1)
    }

    @Test(arguments: ["own", "guest", "grouped"])
    func followedForumsDisplayNativeRowsAndPreservePaging(_ sample: String) throws {
        let root = try #require(Bundle(for: U12ForumsBundleToken.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/UserProfile/native-forums.json"))
        let fixtures = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let response = try #require(fixtures[sample])
        let data = try JSONSerialization.data(withJSONObject: response)
        let page = try NativeProfileProtocol.forums(data, cursor: .init(page: 2, lastThreadTime: nil))
        #expect(page.forums.map(\.forumID) == [13_001, 13_002])
        let first = try #require(page.forums.first)
        #expect(first.name == "开源开发")
        #expect(first.memberCount == 120)
        #expect(first.levelID == 7)
        #expect(first.avatarResourceID == "https://fixture.invalid/forum.png")
        #expect(page.forums.last?.name == "示例吧")
        #expect(page.next?.page == (sample == "own" ? nil : 3))
    }

    @Test func invalidForumRowsCannotMasqueradeAsSuccessfulEmptyContent() throws {
        for list in [#"[{"forum_id":"13001","forum_name":"错误模型"}]"#,
                     #"[{"id":0,"name":"无效身份"}]"#,
                     #"{"unexpected":[{"id":13001,"name":"错误结构"}]}"#,
                     #"{"gconforum":"invalid","non-gconforum":[]}"#] {
            let bytes = Data("{\"error_code\":\"0\",\"has_more\":0,\"forum_list\":\(list)}".utf8)
            #expect(throws: ProfileContentFailure.invalidData) {
                try NativeProfileProtocol.forums(bytes, cursor: nil)
            }
        }
        let empty = Data(#"{"error_code":"0","has_more":0,"forum_list":[]}"#.utf8)
        let page = try NativeProfileProtocol.forums(empty, cursor: nil)
        #expect(page.forums.isEmpty)
        #expect(page.next == nil)
        for json in [#"{"error_code":0,"has_more":0}"#, #"{"error_code":0,"forum_list":[]}"#,
                     #"{"error_code":0,"forum_list":null}"#, #"{}"#] {
            #expect(throws: ProfileContentFailure.invalidData) {
                try NativeProfileProtocol.forums(Data(json.utf8), cursor: nil)
            }
        }
    }
}

private actor ForumAvailabilityFixture {
    static let unavailable = Data(#"{"error_code":"0","ctime":0,"logid":"fixture","server_time":0,"time":0}"#.utf8)
    static let visible = Data(#"{"error_code":"0","has_more":1,"forum_list":[{"id":13001,"name":"Fixture"}]}"#.utf8)
    private var body = visible
    private var networkFailure = false
    private(set) var reads = 0
    func set(_ bytes: Data) { body = bytes }
    func fail(_ kind: String) {
        networkFailure = kind == "network"
        body = Data((kind == "server" ? #"{"error_code":123}"# : #"{"error_code":0,"forum_list":null}"#).utf8)
    }
    func read() throws -> HTTPResponse {
        reads += 1
        if networkFailure { throw URLError(.timedOut) }
        return .init(statusCode: 200, headers: [:], body: body)
    }
}

private final class U12ForumsBundleToken: NSObject {}
