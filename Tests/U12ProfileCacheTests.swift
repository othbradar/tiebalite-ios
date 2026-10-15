import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U12ProfileCacheTests {
    @Test func concurrentRelationshipEntriesSubmitOneWriteOnly() async throws {
        let scope = ContentCacheContext(namespace: "fixture-a", revision: 1)
        let gate = NativeTBSGateClient()
        let repository = CachedProfileContentRepository(cache: ContentPageCache(directory: nil), scheduler: ContentLoadScheduler(),
                                                        context: { scope }, execute: { _, _ in
            try await gate.execute(HTTPRequest(method: .post, url: #require(URL(string: "https://fixture.invalid/follow"))))
        })
        let user = try #require(UserProfileRoute(userID: 42, fallbackDisplayName: "Fixture"))
        let operation = Task { try await repository.setFollowing(true, user: user, portrait: "fixture", scope: scope) }
        await gate.waitForRequest()
        await #expect(throws: ProfileContentFailure.relationshipUnavailable) {
            try await repository.setFollowing(true, user: user, portrait: "fixture", scope: scope)
        }
        await gate.complete(.success(.init(statusCode: 200, headers: [:], body: Data(#"{"error_code":"0"}"#.utf8))))
        try await operation.value
        #expect(await gate.requestCount == 1)
    }

    @Test func sameQuerySharesOneSourceAndRestoresOnlyMatchingCache() async throws {
        let scope = ContentCacheContext(namespace: "fixture-a", revision: 1)
        let gate = NativeTBSGateClient(), cache = ContentPageCache(directory: nil), scheduler = ContentLoadScheduler()
        let repository = CachedProfileContentRepository(
            cache: cache, scheduler: scheduler, context: { scope }, execute: { _, _ in
                try await gate.execute(HTTPRequest(method: .post, url: #require(URL(string: "https://fixture.invalid/profile"))))
            })
        let user = try #require(UserProfileRoute(userID: 42, fallbackDisplayName: "Fixture"))
        let route = ProfileListRoute(user: user, section: .threads)
        let first = Task { try await repository.load(route, cursor: nil, scope: scope) }
        await gate.waitForRequest()
        let second = Task { try await repository.load(route, cursor: nil, scope: scope) }
        for _ in 0..<10_000 {
            if await scheduler.diagnostics().merged == 1 { break }
            await Task.yield()
        }
        #expect(await scheduler.diagnostics().merged == 1)
        await gate.complete(.success(.init(statusCode: 200, headers: [:], body: try response())))
        #expect(try await first.value == second.value)
        #expect(await gate.requestCount == 1)
        #expect(await repository.cached(route, scope: scope)?.posts.map(\.id) == [110])
        #expect(await repository.cached(.init(user: user, section: .replies), scope: scope) == nil)
        #expect(await repository.cached(route, scope: .init(namespace: "fixture-b", revision: 2)) == nil)
    }

    @Test(arguments: [false, true])
    func cacheClearOrAccountChangeRejectsOldResponse(accountChange: Bool) async throws {
        let scope = ContentCacheContext(namespace: "fixture-a", revision: 1)
        let current = ProfileScopeBox(scope)
        let gate = NativeTBSGateClient(), cache = ContentPageCache(directory: nil)
        let repository = CachedProfileContentRepository(
            cache: cache, scheduler: ContentLoadScheduler(), context: { current.value }, execute: { _, _ in
                try await gate.execute(HTTPRequest(method: .post, url: #require(URL(string: "https://fixture.invalid/profile"))))
            })
        let user = try #require(UserProfileRoute(userID: 42, fallbackDisplayName: "Fixture"))
        let route = ProfileListRoute(user: user, section: .threads)
        let operation = Task { try await repository.load(route, cursor: nil, scope: scope) }
        await gate.waitForRequest()
        if accountChange { current.value = .init(namespace: "fixture-b", revision: 2) } else { await cache.clear() }
        await gate.complete(.success(.init(statusCode: 200, headers: [:], body: try response())))
        await #expect(throws: CancellationError.self) { try await operation.value }
        current.value = scope
        #expect(await repository.cached(route, scope: scope) == nil)
    }

    private func response() throws -> Data {
        var response = TiebaNativeProfiles_Response()
        var post = TiebaNativeProfiles_Post()
        post.threadID = 110; post.postID = 111; post.userID = 42; post.title = "Fixture"
        response.data.postList = [post]
        return try response.serializedData()
    }
}
