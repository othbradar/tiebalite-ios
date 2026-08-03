import Foundation

enum FixtureReadingImageResource {
    static let blue = "stage10.fixture.image.blue"
    static let green = "stage10.fixture.image.green"
    static let orange = "stage10.fixture.image.orange"
    static let fetchFailure = "stage10.fixture.image.fetch-failure"
}

struct FixtureReadingImageLoader: ImageLoading {
    func load(_ request: ImageRequest) async throws -> ImagePayload {
        try Task.checkCancellation()
        let data: Data
        switch request.resourceID {
        case FixtureReadingImageResource.blue:
            data = Self.bluePNG
        case FixtureReadingImageResource.green:
            data = Self.greenPNG
        case FixtureReadingImageResource.orange:
            data = Self.orangePNG
        case FixtureReadingImageResource.fetchFailure:
            throw ImageLoadingError.unavailable
        default:
            throw ImageLoadingError.missingFixture
        }
        return ImagePayload(data: data, mediaType: "image/png")
    }

    private static let fallbackPNG = Data([
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

    private static let bluePNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP8z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
    ) ?? fallbackPNG

    private static let greenPNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mNk+M8AAAICAQB7CY9eAAAAAElFTkSuQmCC"
    ) ?? fallbackPNG

    private static let orangePNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mNgYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC"
    ) ?? fallbackPNG
}
