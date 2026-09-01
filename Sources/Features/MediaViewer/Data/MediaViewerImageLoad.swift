import UIKit

enum MediaViewerImagePhase: Equatable, Sendable {
    case cancelled
    case failedToDecode
    case failedToFetch
    case idle
    case loading
    case rendered
}

@MainActor
struct MediaViewerImageLoadOutcome {
    let phase: MediaViewerImagePhase
    let image: UIImage?
}

@MainActor
enum MediaViewerImageLoad {
    static func resolve(
        request: ImageRequest,
        using imageLoader: any ImageLoading
    ) async throws -> MediaViewerImageLoadOutcome {
        do {
            let payload = try await imageLoader.load(request)
            try Task.checkCancellation()
            guard let image = payload.displayImage() else {
                return MediaViewerImageLoadOutcome(
                    phase: .failedToDecode,
                    image: nil
                )
            }
            return MediaViewerImageLoadOutcome(
                phase: .rendered,
                image: image
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch ImageLoadingError.decodingFailed {
            try Task.checkCancellation()
            return MediaViewerImageLoadOutcome(
                phase: .failedToDecode,
                image: nil
            )
        } catch ImageLoadingError.sourceDimensionsTooLarge {
            try Task.checkCancellation()
            return MediaViewerImageLoadOutcome(
                phase: .failedToDecode,
                image: nil
            )
        } catch {
            try Task.checkCancellation()
            return MediaViewerImageLoadOutcome(
                phase: .failedToFetch,
                image: nil
            )
        }
    }
}
