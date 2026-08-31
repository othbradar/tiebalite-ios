import UIKit

enum ThreadContentImagePhase: CaseIterable, Equatable, Sendable {
    case cancelled
    case failedToDecode
    case failedToFetch
    case idle
    case loading
    case rendered

    var accessibilityValue: String {
        switch self {
        case .cancelled:
            ThreadContentImageCopy.cancelledAccessibilityValue
        case .failedToDecode, .failedToFetch:
            ThreadContentImageCopy.failureAccessibilityValue
        case .idle:
            ThreadContentImageCopy.idleAccessibilityValue
        case .loading:
            ThreadContentImageCopy.loadingAccessibilityValue
        case .rendered:
            ThreadContentImageCopy.renderedAccessibilityValue
        }
    }
}

enum ThreadContentImageCopy {
    static let cancelledAccessibilityValue = "加载已取消"
    static let cancelledMessage = "图片加载已取消"
    static let failureAccessibilityValue = "加载失败"
    static let failureMessage = "图片暂不可用"
    static let idleAccessibilityValue = "尚未加载"
    static let idleMessage = "图片等待加载"
    static let loadingAccessibilityValue = "正在加载"
    static let loadingMessage = "图片加载中"
    static let openMediaHint = "打开图片查看器"
    static let renderedAccessibilityValue = "已加载"
}

@MainActor
enum ThreadContentImageRenderState {
    case cancelled(ThreadImageRequestDescriptor)
    case failedToDecode(ThreadImageRequestDescriptor)
    case failedToFetch(ThreadImageRequestDescriptor)
    case idle
    case loading(ThreadImageRequestDescriptor)
    case rendered(ThreadImageRequestDescriptor, UIImage)

    var phase: ThreadContentImagePhase {
        switch self {
        case .cancelled:
            .cancelled
        case .failedToDecode:
            .failedToDecode
        case .failedToFetch:
            .failedToFetch
        case .idle:
            .idle
        case .loading:
            .loading
        case .rendered:
            .rendered
        }
    }

    static func decoding(
        _ payload: ImagePayload,
        for request: ThreadImageRequestDescriptor
    ) -> Self {
        guard let image = UIImage(data: payload.data)?.preparingForDisplay() else {
            return .failedToDecode(request)
        }
        return .rendered(request, image)
    }

    func projected(
        for currentRequest: ThreadImageRequestDescriptor
    ) -> Self {
        switch self {
        case .idle:
            .idle
        case let .cancelled(request),
             let .failedToDecode(request),
             let .failedToFetch(request),
             let .loading(request),
             let .rendered(request, _):
            request == currentRequest ? self : .idle
        }
    }

    func mediaIntent(
        from candidate: ThreadMediaIntent?
    ) -> ThreadMediaIntent? {
        guard case let .rendered(request, _) = self,
              let candidate,
              let selectedItem = candidate.items.first(where: {
                  $0.mediaID == candidate.initialMediaID
              }),
              selectedItem.request == request else {
            return nil
        }
        return candidate
    }
}

enum ThreadContentImageLoad {
    @MainActor
    static func resolve(
        _ request: ThreadImageRequestDescriptor,
        using imageLoader: any ImageLoading
    ) async throws -> ThreadContentImageRenderState {
        guard request.isLoadable else {
            return .failedToFetch(request)
        }
        do {
            let payload = try await imageLoader.load(
                ImageRequest(resourceID: request.resourceID)
            )
            try Task.checkCancellation()
            return .decoding(payload, for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            return .failedToFetch(request)
        }
    }
}

enum ThreadContentImagePresentation {
    static let minimumLayoutAspectRatio = 0.5
    static let maximumLayoutAspectRatio = 3.0

    static func layoutAspectRatio(
        dimensions: ThreadMediaDimensions,
        phase: ThreadContentImagePhase
    ) -> Double {
        _ = phase
        return min(
            maximumLayoutAspectRatio,
            max(minimumLayoutAspectRatio, dimensions.layoutAspectRatio)
        )
    }

    static func accessibilityLabel(
        alternativeText: String,
        mediaIntent: ThreadMediaIntent?
    ) -> String {
        guard let mediaIntent,
              let index = mediaIntent.items.firstIndex(where: {
                  $0.mediaID == mediaIntent.initialMediaID
              }) else {
            return MediaAccessibilityCopy.imageLabel(
                alternativeText: alternativeText,
                position: 0,
                total: 0
            )
        }
        return MediaAccessibilityCopy.imageLabel(
            alternativeText: alternativeText,
            position: index + 1,
            total: mediaIntent.items.count
        )
    }
}
