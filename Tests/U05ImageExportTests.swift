import Foundation
import ImageIO
import Testing
@testable import TiebaLite

@MainActor
@Suite("U05 captured image file export")
struct U05ImageExportTests {
    @Test func sourceBytesPreserveOrientationAndNeverUseDisplayBitmap() async throws {
        let bytes = try TestImageFixtureFactory.exifRotatedJPEG(width: 40, height: 20)
        let transport = ExportTestTransport(bytes: bytes)
        let fetcher = OriginalImageFileFetcher(loader: transport)
        let file = try await fetcher.fetch(request(2))
        #expect(try Data(contentsOf: file.url) == bytes)
        #expect(file.typeIdentifier == "public.jpeg")
        #expect(file.isOriginal)
        let source = try #require(CGImageSourceCreateWithURL(file.url as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyOrientation] as? Int == 6)
        #expect(await transport.requests.count == 1)
        let sent = try #require(await transport.requests.first)
        #expect(!sent.httpShouldHandleCookies)
        #expect(sent.allHTTPHeaderFields?["Cookie"] == nil)
        #expect(sent.allHTTPHeaderFields?["Authorization"] == nil)
        await fetcher.remove(file)
        #expect(!FileManager.default.fileExists(atPath: file.url.path))
    }

    @Test func permissionDeniedDoesNotDownloadOrReportSuccessAndCanRetry() async throws {
        let fixture = try ExportTestFixture()
        await fixture.writer.setFailure(.permissionDenied)
        let store = fixture.store()
        store.start(request(2), action: .save)
        await store.waitForOperation()
        #expect(store.failure == .permissionDenied)
        #expect(await fixture.transport.requests.isEmpty)
        await fixture.writer.setFailure(nil)
        store.retry()
        await store.waitForOperation()
        #expect(store.state == .saved)
        #expect(await fixture.writer.writtenIDs == ["media-2"])
    }

    @Test func switchingImageAndRepeatedTapCannotReplaceCapturedResourceOrWriteTwice() async throws {
        let fixture = try ExportTestFixture(holdWrites: true)
        let store = fixture.store()
        store.start(request(2), action: .save)
        await fixture.writer.waitForWrite()
        store.start(request(3), action: .save)
        #expect(store.capturedRequest?.mediaID == "media-2")
        #expect(store.state == .writing)
        #expect(await fixture.writer.fileExistsDuringWrite)
        await fixture.writer.finishWrite()
        await store.waitForOperation()
        #expect(store.state == .saved)
        #expect(await fixture.writer.writtenIDs == ["media-2"])
        #expect(await fixture.transport.requests.count == 1)
        #expect(await fixture.writer.filesWereRemoved)
    }

    @Test(arguments: [ImageExportFailure.download, .write, .unsupportedFormat])
    func failureIsDistinctAndRetryable(failure: ImageExportFailure) async throws {
        let fixture = try ExportTestFixture()
        if failure == .download { await fixture.transport.setFails(true) } else { await fixture.writer.setFailure(failure) }
        let store = fixture.store()
        store.start(request(2), action: .save)
        await store.waitForOperation()
        #expect(store.failure == failure)
        #expect(await fixture.writer.filesWereRemoved)
        await fixture.transport.setFails(false)
        await fixture.writer.setFailure(nil)
        store.retry()
        await store.waitForOperation()
        #expect(store.state == .saved)
    }

    @Test(arguments: [false, true])
    func shareKeepsActualFileUntilSystemCompletesOrCancels(completed: Bool) async throws {
        let fixture = try ExportTestFixture()
        let store = fixture.store()
        store.start(request(2), action: .share)
        await store.waitForOperation()
        let file = try #require(store.shareFile)
        #expect(try Data(contentsOf: file.url) == fixture.bytes)
        #expect(await fixture.writer.authorizationCount == 0)
        store.shareDidPresent()
        store.cancel() // Dismissing the owner must not remove a file still held by the system.
        #expect(FileManager.default.fileExists(atPath: file.url.path))
        store.shareFinished(completed: completed)
        await store.waitForOperation()
        #expect(!FileManager.default.fileExists(atPath: file.url.path))
        #expect(store.shareFile == nil)
    }

    @Test func savingDoesNotFallBackToPreviewWhenOriginalFails() async throws {
        let fixture = try ExportTestFixture()
        await fixture.transport.setFailOriginal(true)
        let store = fixture.store()
        store.start(request(2), action: .save)
        await store.waitForOperation()
        #expect(store.state == .failed)
        #expect(store.failure == .download)
        #expect(await fixture.writer.writtenIDs.isEmpty)
        #expect(await fixture.transport.requests.compactMap { $0.url?.path } == ["/original-2"])
    }

    @Test func missingOriginalNeverSavesPreviewOrGuessesAnOriginalURL() async throws {
        let fixture = try ExportTestFixture()
        let available = request(2)
        let original = available.descriptor.originalOnly.imageRequest(
            purpose: .mediaViewer, targetPixelSize: .init(width: 100, height: 100))
        #expect(original.candidateURLs.count == 1)
        #expect(original.candidateURLs[0].hasSuffix("/original-2"))
        let preview = ThreadImageRequestDescriptor(resourceID: available.descriptor.resourceID,
                                                   candidates: available.descriptor.candidates.filter { $0.role != .original })
        #expect(preview.originalOnly.candidates.isEmpty)
        let store = fixture.store()
        store.start(.init(mediaID: available.mediaID, position: 2, descriptor: preview), action: .save)
        await store.waitForOperation()
        #expect(store.failure == .originalUnavailable)
        #expect(await fixture.transport.requests.isEmpty)
        #expect(await fixture.writer.writtenIDs.isEmpty)
    }

    @Test func shareFallbackIsExplicitAndUsesReturnedCandidateOnly() async throws {
        let fixture = try ExportTestFixture()
        await fixture.transport.setFailOriginal(true)
        let store = fixture.store()
        store.start(request(2), action: .share)
        await store.waitForOperation()
        #expect(store.state == .readyToShare)
        #expect(store.isAvailableVersion)
        #expect(store.statusText.contains("非原图"))
        let paths = await fixture.transport.requests.compactMap { $0.url?.path }
        #expect(paths == ["/original-2", "/preview-2"])
        store.shareFinished(completed: false)
        await store.waitForOperation()
    }

    @Test func closingBeforeSharePresentationRemovesUnclaimedFile() async throws {
        let fixture = try ExportTestFixture()
        let store = fixture.store()
        store.start(request(2), action: .share)
        await store.waitForOperation()
        let file = try #require(store.shareFile)
        #expect(store.state == .readyToShare)
        store.cancel()
        await store.waitForOperation()
        #expect(store.shareFile == nil)
        #expect(!FileManager.default.fileExists(atPath: file.url.path))
    }

    @Test func closingDuringNoncancellablePhotoWriteKeepsFileUntilCallback() async throws {
        let fixture = try ExportTestFixture(holdWrites: true)
        let store = fixture.store()
        store.start(request(2), action: .save)
        await fixture.writer.waitForWrite()
        store.cancel()
        #expect(await fixture.writer.fileExistsDuringWrite)
        await fixture.writer.finishWrite()
        await store.waitForOperation()
        #expect(await fixture.writer.filesWereRemoved)
        #expect(store.state == .idle)
    }

    @Test func animatedGIFRetainsAllEncodedFrames() async throws {
        let bytes = try TestImageFixtureFactory.animatedGIF()
        let fetcher = OriginalImageFileFetcher(loader: ExportTestTransport(bytes: bytes))
        let file = try await fetcher.fetch(request(2))
        #expect(try Data(contentsOf: file.url) == bytes)
        #expect(file.typeIdentifier == "com.compuserve.gif")
        let source = try #require(CGImageSourceCreateWithURL(file.url as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 2)
        await fetcher.remove(file)
    }

    @Test func transparentPNGIsNotConvertedToOpaqueJPEGDespiteMisleadingMIME() async throws {
        let bytes = try TestImageFixtureFactory.png(width: 32, height: 16, alpha: 0.25)
        let fetcher = OriginalImageFileFetcher(loader: ExportTestTransport(bytes: bytes))
        let file = try await fetcher.fetch(request(2))
        #expect(try Data(contentsOf: file.url) == bytes)
        #expect(file.typeIdentifier == "public.png")
        let source = try #require(CGImageSourceCreateWithURL(file.url as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyHasAlpha] as? Bool == true)
        await fetcher.remove(file)
    }

    @Test(arguments: [false, true])
    func malformedOrOversizedFilesNeverReachPhotoWriter(oversized: Bool) async throws {
        let bytes = oversized ? try TestImageFixtureFactory.png(width: 32, height: 16) : Data("not an image".utf8)
        let writer = ExportTestWriter(holdWrites: false)
        let fetcher = OriginalImageFileFetcher(loader: ExportTestTransport(bytes: bytes), maximumByteCount: oversized ? 1 : 1_024)
        let store = MediaExportStore(fetcher: fetcher, writer: writer)
        store.start(request(2), action: .save)
        await store.waitForOperation()
        #expect(store.failure == .download)
        #expect(await writer.writtenIDs.isEmpty)
    }

    private func request(_ number: Int) -> ImageExportRequest {
        ImageExportRequest(mediaID: "media-\(number)", position: number, descriptor: .init(
            resourceID: "resource-\(number)", candidates: [
                .init(role: .cdn, destination: .init(absoluteString: "https://fixture.invalid/preview-\(number)", scheme: .https)),
                .init(role: .original, destination: .init(absoluteString: "https://fixture.invalid/original-\(number)", scheme: .https))
            ]))
    }
}
