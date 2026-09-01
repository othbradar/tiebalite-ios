import Foundation
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct MediaViewerPresentationTests {
    @Test
    func intentMappingPreservesStableOrderAndInitialMedia() throws {
        let items = (0..<3).map(makeItem)
        let intent = ThreadMediaIntent(
            initialMediaID: items[1].mediaID,
            items: items
        )

        let presentation = try #require(
            MediaViewerPresentation(intent: intent)
        )

        #expect(presentation.items.map(\.id) == items.map {
            $0.mediaID.stableKey
        })
        #expect(presentation.initialMediaID == items[1].mediaID.stableKey)
        #expect(presentation.id.orderedMediaIDs == items.map {
            $0.mediaID.stableKey
        })
        #expect(presentation.items.map(\.accessibilityLabel) == [
            "Fixture image 0，第 1 张，共 3 张",
            "Fixture image 1，第 2 张，共 3 张",
            "Fixture image 2，第 3 张，共 3 张"
        ])
    }

    @Test
    func presentationRejectsMissingInitialOrDuplicateStableMediaID() {
        let first = makeItem(0)
        let missing = makeItem(9)

        #expect(MediaViewerPresentation(intent: ThreadMediaIntent(
            initialMediaID: missing.mediaID,
            items: [first]
        )) == nil)
        #expect(MediaViewerPresentation(intent: ThreadMediaIntent(
            initialMediaID: first.mediaID,
            items: [first, first]
        )) == nil)
    }

    private func makeItem(_ ordinal: Int) -> ThreadMediaItem {
        let source = ThreadContentSource(
            threadID: 51,
            postID: 61,
            scope: .firstPost
        )
        let nodeID = ThreadContentNodeID(source: source, ordinal: ordinal)
        return ThreadMediaItem(
            mediaID: ThreadMediaID(sourceNodeID: nodeID),
            sourceNodeID: nodeID,
            request: ThreadImageRequestDescriptor(
                resourceID: "media-viewer-fixture.\(ordinal)",
                candidates: [ThreadImageCandidate(
                    role: .source,
                    destination: ValidatedWebDestination(
                        absoluteString: "https://fixture.invalid/media/\(ordinal).png",
                        scheme: .https
                    )
                )]
            ),
            dimensions: .known(width: 640, height: 480),
            alternativeText: "Fixture image \(ordinal)"
        )
    }
}

@MainActor
struct MediaViewerImageLoadTests {
    @Test
    func validBytesBecomeRenderedImage() async throws {
        let outcome = try await MediaViewerImageLoad.resolve(
            request: ImageRequest(resourceID: "valid"),
            using: MediaViewerTestImageLoader(
                behavior: .payload(Self.pixelPNG)
            )
        )

        #expect(outcome.phase == .rendered)
        #expect(outcome.image != nil)
    }

    @Test
    func predecodedPayloadRendersAndPreservesViewerRequest() async throws {
        let bytes = try TestImageFixtureFactory.png(width: 32, height: 16)
        let image = try #require(UIImage(data: bytes))
        let loader = HarnessCapturingImageLoader(
            payload: ImagePayload(
                decodedImage: image,
                mediaType: "image/png",
                pixelSize: ImageTargetPixelSize(width: 32, height: 16)
            )
        )
        let request = ImageRequest(
            resourceID: "viewer-predecoded",
            candidateURLs: ["https://images.fixture.invalid/viewer.png"],
            targetPixelSize: ImageTargetPixelSize(width: 2_048, height: 2_048),
            purpose: .mediaViewer,
            resizeMode: .fit
        )

        let outcome = try await MediaViewerImageLoad.resolve(
            request: request,
            using: loader
        )

        #expect(outcome.phase == .rendered)
        #expect(outcome.image != nil)
        #expect(await loader.recordedRequests() == [request])
    }

    @Test(arguments: [
        ImageLoadingError.decodingFailed,
        .sourceDimensionsTooLarge
    ])
    func loaderDecodeFailuresRemainDecodeFailures(
        error: ImageLoadingError
    ) async throws {
        let outcome = try await MediaViewerImageLoad.resolve(
            request: ImageRequest(resourceID: "decode-error"),
            using: HarnessFailingImageLoader(error: error)
        )

        #expect(outcome.phase == .failedToDecode)
        #expect(outcome.image == nil)
    }

    @Test(arguments: [
        ImageLoadingError.decodingFailed,
        .sourceDimensionsTooLarge
    ])
    func cancellationWinsOverALateTypedDecodeFailure(
        error: ImageLoadingError
    ) async throws {
        let loader = HarnessCancellationAsImageFailureLoader(error: error)
        let task = Task { @MainActor in
            try await MediaViewerImageLoad.resolve(
                request: ImageRequest(resourceID: "cancelled-decode"),
                using: loader
            )
        }
        try await loader.waitUntilStarted()

        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    @Test(arguments: [
        MediaViewerTestImageLoader.Behavior.failure,
        .payload(Data([0x00, 0x01, 0x02, 0x03]))
    ])
    func fetchAndDecodeFailuresRemainDistinct(
        behavior: MediaViewerTestImageLoader.Behavior
    ) async throws {
        let outcome = try await MediaViewerImageLoad.resolve(
            request: ImageRequest(resourceID: "failure"),
            using: MediaViewerTestImageLoader(behavior: behavior)
        )

        switch behavior {
        case .failure:
            #expect(outcome.phase == .failedToFetch)
        case .payload:
            #expect(outcome.phase == .failedToDecode)
        case .cancelled:
            Issue.record("Cancellation is covered separately")
        }
        #expect(outcome.image == nil)
    }

    @Test
    func cancellationRemainsCancellation() async {
        await #expect(throws: CancellationError.self) {
            _ = try await MediaViewerImageLoad.resolve(
                request: ImageRequest(resourceID: "cancelled"),
                using: MediaViewerTestImageLoader(behavior: .cancelled)
            )
        }
    }

    @Test
    func cancellationDropsALateSuccessfulImagePayload() async throws {
        let loader = MediaViewerLateSuccessImageLoader()
        let task = Task { @MainActor in
            try await MediaViewerImageLoad.resolve(
                request: ImageRequest(resourceID: "late-success"),
                using: loader
            )
        }
        try await loader.waitUntilStarted()

        task.cancel()
        loader.succeed(with: Self.pixelPNG)

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    private static let pixelPNG = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x04, 0x00, 0x00, 0x00, 0xB5, 0x1C, 0x0C,
        0x02, 0x00, 0x00, 0x00, 0x0B, 0x49, 0x44, 0x41,
        0x54, 0x78, 0xDA, 0x63, 0x64, 0xF8, 0x0F, 0x00,
        0x01, 0x05, 0x01, 0x01, 0x27, 0x18, 0xE3, 0x66,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82
    ])
}

private actor MediaViewerLateSuccessImageLoader: ImageLoading {
    private let started = HarnessContinuationGate<Void>()
    private let response = HarnessContinuationGate<ImagePayload>()

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        _ = request
        started.succeed(())
        return try await response.wait()
    }

    func waitUntilStarted() async throws {
        try await started.wait()
    }

    nonisolated func succeed(with data: Data) {
        response.succeed(ImagePayload(data: data, mediaType: "image/png"))
    }
}

struct MediaViewerTestImageLoader: ImageLoading {
    enum Behavior: Sendable {
        case cancelled
        case failure
        case payload(Data)
    }

    let behavior: Behavior

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        _ = request
        switch behavior {
        case .cancelled:
            throw CancellationError()
        case .failure:
            throw ImageLoadingError.unavailable
        case let .payload(data):
            return ImagePayload(data: data, mediaType: "image/png")
        }
    }
}
