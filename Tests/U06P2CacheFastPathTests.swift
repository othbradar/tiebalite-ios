import Foundation
import Testing
@testable import TiebaLite

struct U06P2CacheFastPathTests {
    @Test func memoryHitsAndPureMissesDoNotRewriteIndex() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ContentPageCache(directory: directory)
        let bytes = Data("fixture-page".utf8)
        #expect(await cache.write(bytes, key: "page", epoch: 0))
        let before = await cache.ioCounts()
        for _ in 0..<30 { #expect(await cache.read(key: "page") == bytes) }
        let hits = await cache.ioCounts()
        #expect(hits.indexFlushes - before.indexFlushes <= 1)
        await cache.flushMaintenance()
        #expect(await cache.ioCounts().indexFlushes - before.indexFlushes == 1)
        let flushed = await cache.ioCounts()
        for _ in 0..<20 { #expect(await cache.read(key: "missing") == nil) }
        #expect(await cache.ioCounts().indexFlushes == flushed.indexFlushes)
        let empty = ContentPageCache(directory: directory.appendingPathComponent("empty"))
        #expect(await empty.read(key: "missing") == nil)
        #expect(await empty.ioCounts().indexFlushes == 0)

        let gate = P2WriteGate()
        let heldDirectory = directory.appendingPathComponent("held")
        let held = ContentPageCache(directory: heldDirectory, beforeMaintenanceFlush: { await gate.waitOnce() })
        #expect(await held.write(bytes, key: "old", epoch: 0))
        _ = await held.read(key: "old")
        let barrier = Task { await held.flushMaintenance() }
        try await gate.started.wait()
        for _ in 0..<30 { #expect(await held.read(key: "old") == bytes) }
        #expect(await held.memoryHits == 31) // Returns while the index writer remains held.
        await held.clear()
        #expect(await held.write(Data("new".utf8), key: "new", epoch: 1))
        gate.release.succeed(())
        await barrier.value
        let rebuilt = ContentPageCache(directory: heldDirectory)
        #expect(await rebuilt.read(key: "old") == nil)
        #expect(await rebuilt.read(key: "new") == Data("new".utf8))
        await rebuilt.flushMaintenance()

        let badDirectory = directory.appendingPathComponent("not-a-directory")
        try bytes.write(to: badDirectory)
        let failed = ContentPageCache(directory: badDirectory)
        #expect(await failed.write(bytes, key: "page", epoch: 0) == false)
        #expect(await failed.contains(keys: ["page"], epoch: 0) == false)
    }

    @MainActor
    @Test(arguments: [1, 3])
    func forumAnchorWritesOnlyManifestRegardlessOfPageCount(pageCount: Int) async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = R05ForumFixture()
        let cache = ContentPageCache(directory: directory)
        let scope = P2ContentScope()
        let repository = CachedForumHomeRepository(source: source, cache: cache, context: { scope.context })
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let request = ForumHomePageRequest(route: route)
        var reading = try await repository.fetchPage(request, continuing: nil)
        for page in 1..<pageCount {
            let next = ForumHomePageRequest(route: route, pageNumber: page + 1,
                                            lastThreadID: reading.pages.last?.page.lastThreadID ?? 0)
            reading = try await repository.fetchPage(next, continuing: reading)
        }
        await repository.saveReading(reading, request: request)
        await cache.flushMaintenance()
        reading.anchor = reading.snapshot?.threads.last?.threadID
        let reads = await cache.readRequests
        let counts = await cache.ioCounts()
        await repository.saveReading(reading, request: request)
        #expect(await cache.readRequests - reads == 3) // Manifest + two alias checks, zero old page reads.
        #expect(await cache.ioCounts().writes - counts.writes == 1)
        #expect(await cache.ioCounts().reads - counts.reads == 0)
        await cache.flushMaintenance()
        let rebuiltCache = ContentPageCache(directory: directory)
        let rebuilt = CachedForumHomeRepository(source: source, cache: rebuiltCache)
        let restored = try #require(await rebuilt.restoreReading(request))
        #expect(restored.anchor == reading.anchor && restored.pages.count == pageCount)
        #expect(await source.recordedRequests().count == pageCount)
        scope.context = .init(namespace: "other", revision: 1)
        await repository.saveReading(reading, request: request)
        #expect(await repository.restoreReading(request) == nil)
        await rebuiltCache.flushMaintenance()
        await cache.clear()
        scope.context = .anonymous
        await repository.saveReading(reading, request: request)
        #expect(await repository.restoreReading(request) == nil)
    }

    @Test func diskHitReturnsWhileAllFourNetworkSlotsAreHeld() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = try TestImageFixtureFactory.png(width: 40, height: 20)
        let seed = ImageResourceStore(loader: ImageCacheTestTransport(bytes: bytes), directory: directory)
        _ = try await seed.data(for: request("cached"), maximumByteCount: 1_000_000)
        await seed.flushPersistence()
        let source = P2HeldImageSource(bytes: bytes)
        let store = ImageResourceStore(loader: source, directory: directory)
        let blocked = (0..<4).map { index in
            Task { try await store.data(for: request("blocked-\(index)"), maximumByteCount: 1_000_000) }
        }
        while await source.requests != 4 { await Task.yield() }
        let result = P2Completion()
        let cached = Task {
            let data = try await store.data(for: request("cached"), maximumByteCount: 1_000_000).0
            await result.finish()
            return data
        }
        // Observe either completion or admission into the blocked network queue;
        // no speed threshold is used, and no download gate has been released.
        while !(await result.finished), await store.downloadCounts().queued == 0 { await Task.yield() }
        #expect(await result.finished)
        #expect(await store.downloadCounts().active == 4)
        #expect(await source.requests == 4)
        await source.releaseAll()
        #expect(try await cached.value == bytes)
        for task in blocked { _ = try await task.value }
        await store.flushPersistence()
    }

    @Test func pendingImageWriteIsBoundedSharedAndEpochSafeAndExportSurvivesClear() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = try TestImageFixtureFactory.animatedGIF()
        let source = P2HeldImageSource(bytes: bytes)
        let gate = P2WriteGate()
        let store = ImageResourceStore(loader: source, directory: directory, beforeDiskWrite: { await gate.waitOnce() })
        let first = Task { try await store.data(for: request("same"), maximumByteCount: 1_000_000) }
        while await source.requests == 0 { await Task.yield() }
        let second = Task { try await store.data(for: request("same"), maximumByteCount: 1_000_000) }
        while await store.diagnostics().merged == 0 { await Task.yield() }
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        await source.releaseAll()
        #expect(try await second.value.0 == bytes)
        try await gate.started.wait()
        #expect(await store.diagnostics().committedWrites == 0)
        #expect(try await store.data(for: request("same"), maximumByteCount: 1_000_000).0 == bytes)
        #expect(await source.requests == 1)
        _ = try await store.data(for: request("two"), maximumByteCount: 1_000_000)
        _ = try await store.data(for: request("three"), maximumByteCount: 1_000_000)
        #expect(await store.diagnostics().pendingWrites == 2)
        #expect(await store.diagnostics().pendingWriteBytes == bytes.count * 2)
        #expect(await store.diagnostics().skippedWrites == 1)

        let fetcher = OriginalImageFileFetcher(loader: store)
        let descriptor = ThreadImageRequestDescriptor(resourceID: "same", candidates: [.init(
            role: .original, destination: .init(absoluteString: try #require(request("same").url).absoluteString, scheme: .https))])
        let file = try await fetcher.fetch(.init(mediaID: "same", position: 1, descriptor: descriptor))
        let exportedBytes = try Data(contentsOf: file.url)
        #expect(file.isOriginal && exportedBytes == bytes)
        #expect(await source.requests == 3)
        await store.clear()
        gate.release.succeed(())
        await store.flushPersistence()
        #expect(await store.diagnostics().committedWrites == 0)
        #expect(await store.diagnostics().diskBytes == 0)
        #expect(try Data(contentsOf: file.url) == bytes)
        await fetcher.remove(file)
        _ = try await store.data(for: request("restart"), maximumByteCount: 1_000_000)
        await store.flushPersistence()
        #expect(await store.diagnostics().committedWrites == 1)
        let offline = ImageCacheTestTransport(bytes: bytes)
        await offline.setOffline()
        let rebuilt = ImageResourceStore(loader: offline, directory: directory)
        let loader = ProductionImageLoader(loader: rebuilt)
        let shown = try await loader.load(.init(resourceID: "restart", candidateURLs: [try #require(request("restart").url).absoluteString],
                                                targetPixelSize: .init(width: 40, height: 40), purpose: .mediaViewer))
        #expect(shown.decodedImage != nil)
        #expect(await offline.requests == 0)
        #expect(await rebuilt.diagnostics().diskHits == 1)
        await rebuilt.flushPersistence()
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("u06p2-\(UUID())")
    }
    private func request(_ suffix: String) -> URLRequest {
        URLRequest(url: URL(string: "https://imgsrc.baidu.com/forum/\(suffix)") ?? URL(fileURLWithPath: "/invalid"))
    }
}

@MainActor
private final class P2ContentScope { var context = ContentCacheContext.anonymous }

private actor P2WriteGate {
    let started = HarnessContinuationGate<Void>()
    let release = HarnessContinuationGate<Void>()
    private var held = false
    func waitOnce() async {
        guard !held else { return }
        held = true
        started.succeed(())
        _ = try? await release.wait()
    }
}

private actor P2Completion {
    private(set) var finished = false
    func finish() { finished = true }
}

private actor P2HeldImageSource: HTTPDataLoading {
    let bytes: Data
    private let gates = (0..<4).map { _ in HarnessContinuationGate<Void>() }
    private(set) var requests = 0
    init(bytes: Data) { self.bytes = bytes }
    func releaseAll() { for gate in gates { gate.succeed(()) } }
    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        let index = requests
        requests += 1
        if index < gates.count { try await gates[index].wait() }
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                                    headerFields: ["Content-Type": "image/png"]))
        return (bytes, response)
    }
}
