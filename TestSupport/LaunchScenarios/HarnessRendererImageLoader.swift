import Foundation

#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
final class HarnessRendererImageLoader: ImageLoading, Sendable {
    func load(_ request: ImageRequest) async throws -> ImagePayload {
        try Task.checkCancellation()
        switch request.resourceID {
        case DebugThreadContentRendererFixtures.loadedImageResourceID:
            return ImagePayload(
                data: Self.pixelPNG,
                mediaType: "image/png"
            )
        case DebugThreadContentRendererFixtures.loadingImageResourceID:
            let loadingGate = HarnessContinuationGate<ImagePayload>()
            return try await withTaskCancellationHandler {
                try await loadingGate.wait()
            } onCancel: {
                loadingGate.cancel()
            }
        case DebugThreadContentRendererFixtures.failedImageResourceID:
            throw ImageLoadingError.unavailable
        default:
            throw ImageLoadingError.missingFixture
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
#endif
