import Foundation

struct ImageRequest: Hashable, Sendable {
    let resourceID: String
}

struct ImagePayload: Equatable, Sendable {
    let data: Data
    let mediaType: String
}

enum ImageLoadingError: Error, Equatable, Sendable {
    case missingFixture
    case unavailable
}

protocol ImageLoading: Sendable {
    func load(_ request: ImageRequest) async throws -> ImagePayload
}

struct DisabledImageLoader: ImageLoading {
    func load(_ request: ImageRequest) async throws -> ImagePayload {
        _ = request
        try Task.checkCancellation()
        throw ImageLoadingError.unavailable
    }
}
