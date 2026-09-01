import Foundation
import Testing
@testable import TiebaLite
import UIKit

@Suite("Thread content image render state regressions")
@MainActor
struct ThreadImageRenderStateTests {
    @Test
    func imageAccessibilityLabelUsesStableIntentOrderAndSafeFallback() {
        let intent = fixtureMediaIntent(itemCount: 3, selectedIndex: 1)

        #expect(ThreadContentImagePresentation.accessibilityLabel(
            alternativeText: "图片",
            mediaIntent: intent
        ) == "图片，第 2 张，共 3 张")
        #expect(ThreadContentImagePresentation.accessibilityLabel(
            alternativeText: "   ",
            mediaIntent: nil
        ) == "图片")
        #expect(ThreadContentImageCopy.openMediaHint == "打开图片查看器")
    }

    @Test
    func successfulFetchWithUndecodableBytesDoesNotReportLoaded() async throws {
        let renderState = try await ThreadContentImageLoad.resolve(
            fixtureImageRequest(
                resourceID:
                    DebugThreadContentRendererFixtures.decodeFailedImageResourceID
            ),
            using: HarnessRendererImageLoader()
        )

        #expect(renderState.phase == .failedToDecode)
        #expect(renderState.phase.accessibilityValue == "加载失败")
    }

    @Test
    func validImageBytesReachRenderedState() async throws {
        let renderState = try await ThreadContentImageLoad.resolve(
            fixtureImageRequest(
                resourceID: DebugThreadContentRendererFixtures.loadedImageResourceID
            ),
            using: HarnessRendererImageLoader()
        )

        #expect(renderState.phase == .rendered)
        #expect(renderState.phase.accessibilityValue == "已加载")
    }

    @Test
    func predecodedPayloadRendersAndCarriesPurposeCandidatesAndTarget() async throws {
        let request = fixtureImageRequest(resourceID: "predecoded")
        let bytes = try TestImageFixtureFactory.png(width: 16, height: 8)
        let image = try #require(UIImage(data: bytes))
        let loader = HarnessCapturingImageLoader(
            payload: ImagePayload(
                decodedImage: image,
                mediaType: "image/png",
                pixelSize: ImageTargetPixelSize(width: 16, height: 8)
            )
        )
        let target = ImageTargetPixelSize(width: 640, height: 960)

        let state = try await ThreadContentImageLoad.resolve(
            request,
            using: loader,
            targetPixelSize: target
        )
        let sent = try #require(await loader.recordedRequests().first)

        #expect(state.phase == .rendered)
        #expect(sent.purpose == .threadContent)
        #expect(sent.targetPixelSize == target)
        #expect(sent.candidateURLs == request.candidates.map {
            $0.destination.absoluteString
        })
    }

    @Test(arguments: [
        ImageLoadingError.decodingFailed,
        .sourceDimensionsTooLarge
    ])
    func loaderDecodeFailuresRemainDecodeFailures(
        error: ImageLoadingError
    ) async throws {
        let state = try await ThreadContentImageLoad.resolve(
            fixtureImageRequest(),
            using: HarnessFailingImageLoader(error: error)
        )

        #expect(state.phase == .failedToDecode)
        #expect(state.mediaIntent(from: fixtureMediaIntent()) == nil)
    }

    @Test(arguments: [
        ImageLoadingError.decodingFailed,
        .sourceDimensionsTooLarge
    ])
    func cancellationWinsOverALateTypedDecodeFailure(
        error: ImageLoadingError
    ) async throws {
        let loader = HarnessCancellationAsImageFailureLoader(error: error)
        let task = Task {
            try await ThreadContentImageLoad.resolve(
                fixtureImageRequest(),
                using: loader
            )
        }
        try await loader.waitUntilStarted()

        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    @Test
    func requestFailureRemainsDistinctFromDecodeFailure() async throws {
        let renderState = try await ThreadContentImageLoad.resolve(
            fixtureImageRequest(
                resourceID: DebugThreadContentRendererFixtures.failedImageResourceID
            ),
            using: HarnessRendererImageLoader()
        )

        #expect(renderState.phase == .failedToFetch)
        #expect(renderState.phase.accessibilityValue == "加载失败")
    }

    @Test
    func cancelledImageLoadCannotBecomeFetchFailure() async throws {
        let loader = CancellationAsFailureImageLoader()
        let task = Task {
            try await ThreadContentImageLoad.resolve(
                fixtureImageRequest(),
                using: loader
            )
        }
        try await loader.waitUntilStarted()

        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected image load cancellation")
        } catch is CancellationError {
            return
        } catch {
            Issue.record("Cancellation changed into an image failure")
        }
    }

    @Test
    func everyPhaseHasDeterministicAccessibilityValue() {
        let expectedValues: [(ThreadContentImagePhase, String)] = [
            (.idle, "尚未加载"),
            (.loading, "正在加载"),
            (.rendered, "已加载"),
            (.failedToFetch, "加载失败"),
            (.failedToDecode, "加载失败"),
            (.cancelled, "加载已取消")
        ]

        for (phase, expectedValue) in expectedValues {
            #expect(phase.accessibilityValue == expectedValue)
        }
        #expect(expectedValues.count == ThreadContentImagePhase.allCases.count)
    }

    @Test
    func nonRenderedStatesExposeNoMediaIntent() {
        let request = fixtureImageRequest()
        let intent = fixtureMediaIntent()
        let nonRenderedStates: [ThreadContentImageRenderState] = [
            .idle,
            .loading(request),
            .failedToFetch(request),
            .failedToDecode(request),
            .cancelled(request)
        ]

        for state in nonRenderedStates {
            #expect(state.mediaIntent(from: intent) == nil)
        }
    }

    @Test
    func renderedStatePreservesMediaIntent() async throws {
        let request = fixtureImageRequest(
            resourceID: DebugThreadContentRendererFixtures.loadedImageResourceID
        )
        let renderState = try await ThreadContentImageLoad.resolve(
            request,
            using: HarnessRendererImageLoader()
        )
        let intent = fixtureMediaIntent(request: request)

        #expect(renderState.mediaIntent(from: intent) == intent)
    }

    @Test
    func renderedStateRejectsIntentForAReplacementRequest() async throws {
        let renderedRequest = fixtureImageRequest(
            resourceID: DebugThreadContentRendererFixtures.loadedImageResourceID
        )
        let replacementRequest = fixtureImageRequest(
            resourceID: "fixture.image.replacement"
        )
        let renderState = try await ThreadContentImageLoad.resolve(
            renderedRequest,
            using: HarnessRendererImageLoader()
        )

        #expect(
            renderState.mediaIntent(
                from: fixtureMediaIntent(request: replacementRequest)
            ) == nil
        )
        #expect(
            renderState.projected(for: replacementRequest).phase == .idle
        )
    }

    @Test
    func repeatedDecodeFailurePresentationIsDeterministic() async throws {
        let request = fixtureImageRequest(
            resourceID:
                DebugThreadContentRendererFixtures.decodeFailedImageResourceID
        )
        let loader = HarnessRendererImageLoader()

        let first = try await ThreadContentImageLoad.resolve(
            request,
            using: loader
        )
        let second = try await ThreadContentImageLoad.resolve(
            request,
            using: loader
        )

        #expect(first.phase == second.phase)
        #expect(first.phase == .failedToDecode)
        #expect(
            first.phase.accessibilityValue
                == second.phase.accessibilityValue
        )
        #expect(first.mediaIntent(from: fixtureMediaIntent()) == nil)
        #expect(second.mediaIntent(from: fixtureMediaIntent()) == nil)
    }

    private func fixtureImageRequest(
        resourceID: String = "fixture.image.decode-failure"
    ) -> ThreadImageRequestDescriptor {
        ThreadImageRequestDescriptor(
            resourceID: resourceID,
            candidates: [ThreadImageCandidate(
                role: .source,
                destination: ValidatedWebDestination(
                    absoluteString: "https://fixture.invalid/decode-failure.png",
                    scheme: .https
                )
            )]
        )
    }

    private func fixtureMediaIntent(
        request: ThreadImageRequestDescriptor? = nil
    ) -> ThreadMediaIntent {
        let source = ThreadContentSource(
            threadID: 91_001,
            postID: 92_001,
            scope: .firstPost
        )
        let nodeID = ThreadContentNodeID(source: source, ordinal: 9)
        let mediaID = ThreadMediaID(sourceNodeID: nodeID)
        let resolvedRequest = request ?? fixtureImageRequest()
        return ThreadMediaIntent(
            initialMediaID: mediaID,
            items: [ThreadMediaItem(
                mediaID: mediaID,
                sourceNodeID: nodeID,
                request: resolvedRequest,
                dimensions: .known(width: 640, height: 480),
                alternativeText: "合成图片"
            )]
        )
    }

    private func fixtureMediaIntent(
        itemCount: Int,
        selectedIndex: Int
    ) -> ThreadMediaIntent {
        let source = ThreadContentSource(
            threadID: 91_001,
            postID: 92_001,
            scope: .firstPost
        )
        let items = (0..<itemCount).map { ordinal in
            let nodeID = ThreadContentNodeID(
                source: source,
                ordinal: ordinal
            )
            return ThreadMediaItem(
                mediaID: ThreadMediaID(sourceNodeID: nodeID),
                sourceNodeID: nodeID,
                request: fixtureImageRequest(
                    resourceID: "fixture.image.\(ordinal)"
                ),
                dimensions: .known(width: 640, height: 480),
                alternativeText: "图片"
            )
        }
        return ThreadMediaIntent(
            initialMediaID: items[selectedIndex].mediaID,
            items: items
        )
    }
}

private final class CancellationAsFailureImageLoader: ImageLoading, Sendable {
    private let started = HarnessContinuationGate<Void>()
    private let response = HarnessContinuationGate<ImagePayload>()

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        _ = request
        started.succeed(())
        return try await withTaskCancellationHandler {
            try await response.wait()
        } onCancel: {
            response.fail(ImageLoadingError.unavailable)
        }
    }

    func waitUntilStarted() async throws {
        try await started.wait()
    }
}
