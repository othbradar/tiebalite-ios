import Foundation
import Testing
@testable import TiebaLite

@Suite("U06 encoded image persistence and consumers")
struct U06ImageCacheTests {
    @Test func restartOfflineUsesDiskAndUncachedResourceFails() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = try TestImageFixtureFactory.png(width: 160, height: 80)
        let source = ImageCacheTestTransport(bytes: bytes)
        let first = ImageResourceStore(loader: source, directory: directory)
        let downloaded = try await first.data(for: request(), maximumByteCount: 1_000_000).0
        #expect(downloaded == bytes)
        let offline = ImageCacheTestTransport(bytes: bytes)
        await offline.setOffline()
        let restarted = ImageResourceStore(loader: offline, directory: directory)
        #expect(try await restarted.data(for: request(), maximumByteCount: 1_000_000).0 == bytes)
        #expect(await offline.requests == 0)
        #expect(await restarted.diagnostics().diskHits == 1)
        let displayed = try await ProductionImageLoader(loader: restarted).load(.init(
            resourceID: "offline", candidateURLs: [try #require(request().url).absoluteString],
            targetPixelSize: .init(width: 80, height: 40), purpose: .mediaViewer))
        #expect(displayed.pixelSize == .init(width: 80, height: 40))
        #expect(displayed.decodedImage != nil)
        #expect(await offline.requests == 0)
        await #expect(throws: URLError.self) {
            _ = try await restarted.data(for: request("new"), maximumByteCount: 1_000_000)
        }
        #expect(await offline.requests == 1)
    }

    @Test func twoConsumersShareDownloadAndCancellingOneDoesNotCancelOther() async throws {
        let bytes = try TestImageFixtureFactory.png(width: 80, height: 40)
        let source = ImageCacheTestTransport(bytes: bytes, held: true)
        let store = ImageResourceStore(loader: source, directory: nil)
        let first = Task { try await store.data(for: request(), maximumByteCount: 1_000_000).0 }
        try await source.started.wait()
        let second = Task { try await store.data(for: request(), maximumByteCount: 1_000_000).0 }
        while await store.diagnostics().merged == 0 { await Task.yield() }
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(await source.cancelled == 0)
        source.released.succeed(())
        #expect(try await second.value == bytes)
        #expect(await source.requests == 1)
    }

    @Test func clearRejectsLateCompletionAndCannotDeleteAnExportedFile() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = try TestImageFixtureFactory.animatedGIF()
        let source = ImageCacheTestTransport(bytes: bytes)
        let store = ImageResourceStore(loader: source, directory: directory)
        let fetcher = OriginalImageFileFetcher(loader: store)
        let descriptor = ThreadImageRequestDescriptor(resourceID: "same", candidates: [.init(
            role: .original, destination: .init(absoluteString: try #require(request().url).absoluteString, scheme: .https))])
        let exported = try await fetcher.fetch(.init(mediaID: "first", position: 1, descriptor: descriptor))
        #expect(exported.isOriginal)
        #expect(await store.diagnostics().diskBytes > 0)
        await store.clear()
        #expect(await store.diagnostics().diskBytes == 0)
        #expect(try Data(contentsOf: exported.url) == bytes)
        await fetcher.remove(exported)
        #expect(!FileManager.default.fileExists(atPath: exported.url.path))

        let late = ImageCacheTestTransport(bytes: bytes, held: true)
        let fresh = ImageResourceStore(loader: late, directory: directory)
        let pending = Task { try await fresh.data(for: request(), maximumByteCount: 1_000_000) }
        try await late.started.wait()
        await fresh.clear()
        late.released.succeed(())
        await #expect(throws: CancellationError.self) { try await pending.value }
        #expect(await fresh.diagnostics().diskBytes == 0)
    }

    @Test func targetAndProcessingSeparateBitmapsWhileEncodedDownloadIsShared() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = try TestImageFixtureFactory.png(width: 400, height: 200)
        let source = ImageCacheTestTransport(bytes: bytes)
        let store = ImageResourceStore(loader: source, directory: directory)
        let loader = ProductionImageLoader(loader: store)
        let url = try #require(request().url).absoluteString
        let smallRequest = ImageRequest(resourceID: "same", candidateURLs: [url],
                                        targetPixelSize: .init(width: 40, height: 40), purpose: .listThumbnail, resizeMode: .fill)
        let fullRequest = ImageRequest(resourceID: "same", candidateURLs: [url],
                                       targetPixelSize: .init(width: 400, height: 400), purpose: .mediaViewer, resizeMode: .fit)
        async let smallLoad = loader.load(smallRequest)
        async let fullLoad = loader.load(fullRequest)
        let (small, full) = try await (smallLoad, fullLoad)
        #expect(small.pixelSize == .init(width: 40, height: 40))
        #expect(full.pixelSize == .init(width: 400, height: 200))
        #expect(small.decodedImage !== full.decodedImage)
        #expect(await source.requests == 1)
        let descriptor = ThreadImageRequestDescriptor(resourceID: "same", candidates: [
            .init(role: .original, destination: .init(absoluteString: url, scheme: .https))])
        let fetcher = OriginalImageFileFetcher(loader: store)
        let file = try await fetcher.fetch(.init(mediaID: "same", position: 1, descriptor: descriptor))
        #expect(try Data(contentsOf: file.url) == bytes)
        #expect(await source.requests == 1)
        await fetcher.remove(file)
        await loader.clearImageCache()
        _ = try await loader.load(smallRequest)
        #expect(await source.requests == 2)
    }

    @Test func distinctCDNQueriesDoNotCoalesceAndSignedCandidatesAreNotPersisted() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = ImageCacheTestTransport(bytes: try TestImageFixtureFactory.png(width: 40, height: 20))
        let store = ImageResourceStore(loader: source, directory: directory)
        _ = try await store.data(for: request("same?size=small"), maximumByteCount: 1_000_000)
        _ = try await store.data(for: request("same?size=large"), maximumByteCount: 1_000_000)
        let before = await store.diagnostics().diskBytes
        _ = try await store.data(for: request("same?token=private"), maximumByteCount: 1_000_000)
        #expect(await source.requests == 3)
        #expect(await store.diagnostics().diskBytes == before)
    }

    @Test func diskBudgetEvictsLeastRecentlyUsedAndCorruptionBecomesAMiss() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = ImageCacheTestTransport(bytes: try TestImageFixtureFactory.png(width: 40, height: 20))
        let store = ImageResourceStore(loader: source, directory: directory, policy: .init(maximumEntries: 2))
        for name in ["one", "two", "one", "three", "one"] {
            _ = try await store.data(for: request(name), maximumByteCount: 1_000_000)
        }
        #expect(await source.requests == 3)
        _ = try await store.data(for: request("two"), maximumByteCount: 1_000_000)
        #expect(await source.requests == 4)
        let key = ImageDiskCache.digest(Data(("encoded-v1|anonymous|" + (try #require(request("two").url).absoluteString)).utf8))
        try Data("corrupt".utf8).write(to: directory.appendingPathComponent(key).appendingPathExtension("image"))
        _ = try await store.data(for: request("two"), maximumByteCount: 1_000_000)
        #expect(await source.requests == 5)
        try Data("invalid index".utf8).write(to: directory.appendingPathComponent("index-v1.plist"))
        let rebuilt = ImageResourceStore(loader: source, directory: directory, policy: .init(diskBytes: 1_024, maximumEntries: 2))
        #expect(await rebuilt.diagnostics().diskBytes == 0)
        for name in ["one", "two", "three"] {
            _ = try await rebuilt.data(for: request(name), maximumByteCount: 1_000_000)
        }
        #expect(await rebuilt.diagnostics().diskBytes <= 1_024)
        #expect(await source.requests == 8)
    }

    private func temporaryDirectory() throws -> URL {
        try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                    appropriateFor: FileManager.default.temporaryDirectory, create: true)
    }

    private func request(_ suffix: String = "original") -> URLRequest {
        URLRequest(url: URL(string: "https://imgsrc.baidu.com/forum/\(suffix)") ?? URL(fileURLWithPath: "/invalid"))
    }
}
