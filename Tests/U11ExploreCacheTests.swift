import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U11ExploreCacheTests {
    @Test func persistedPagesKeepDisplayFieldsAndSeparateAccountAndFeed() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("U11-Explore-Cache-Test")
        try? FileManager.default.removeItem(at: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = ExploreTestSource(), scope = ExploreScope()
        let cache = ContentPageCache(directory: directory)
        let repository = CachedExploreFeedRepository(source: source, cache: cache, context: { scope.value })
        let original = try await repository.load(.following, cursor: nil, scope: scope.value)
        _ = try await repository.load(.hot, cursor: nil, scope: scope.value)
        let recreated = CachedExploreFeedRepository(source: source, cache: ContentPageCache(directory: directory), context: { scope.value })
        let restored = try #require(await recreated.cached(.following, scope: scope.value))
        #expect(restored.isFresh && restored.page == original)
        #expect(await recreated.cached(.hot, scope: scope.value)?.page.items.first?.threadID == 210)
        #expect(await source.count == 2)
        scope.value = .init(namespace: "b", revision: 2)
        #expect(await recreated.cached(.following, scope: scope.value) == nil)
        scope.value = .init(namespace: "a", revision: 3)
        await repository.invalidate(.following, scope: scope.value)
        #expect(await repository.cached(.following, scope: scope.value) == nil)
        #expect(await repository.cached(.hot, scope: scope.value) != nil)
    }

    @Test(arguments: [false, true])
    func clearOrAccountChangeRejectsLateResult(changesAccount: Bool) async throws {
        let source = ExploreTestSource(), scope = ExploreScope()
        let cache = ContentPageCache(directory: nil)
        let repository = CachedExploreFeedRepository(source: source, cache: cache, context: { scope.value })
        await source.hold()
        let original = scope.value
        let operation = Task { try await repository.load(.following, cursor: nil, scope: original) }
        try await source.started.wait()
        if changesAccount { scope.value = .init(namespace: "b", revision: 2) } else { await cache.clear() }
        source.release.succeed(())
        await #expect(throws: CancellationError.self) { try await operation.value }
        #expect(await repository.cached(.following, scope: scope.value) == nil)
    }

    @Test func deactivatedPageDoesNotPublishCancelledResponse() async throws {
        let source = ExploreTestSource(), scope = ExploreScope()
        let repository = CachedExploreFeedRepository(source: source, cache: ContentPageCache(directory: nil), context: { scope.value })
        let store = ExploreFeedStore(feed: .following, repository: repository)
        await source.hold()
        let operation = Task { await store.activate(scope: scope.value) }
        try await source.started.wait()
        store.deactivate()
        source.release.succeed(())
        await operation.value
        #expect(store.items.isEmpty && store.state == .idle)
    }
}

@MainActor private final class ExploreScope {
    var value = ContentCacheContext(namespace: "a", revision: 1)
}
