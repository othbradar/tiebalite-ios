import Foundation
import UIKit

enum ImageRequestPurpose: String, Hashable, Sendable {
    case avatar
    case fixture
    case listThumbnail
    case mediaViewer
    case threadContent
}

enum ImageResizeMode: String, Hashable, Sendable {
    case fill
    case fit
}

struct ImageTargetPixelSize: Equatable, Hashable, Sendable {
    static let maximumDimension = 8_192

    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = min(Self.maximumDimension, max(1, width))
        self.height = min(Self.maximumDimension, max(1, height))
    }

    static func normalized(
        pointWidth: Double,
        pointHeight: Double,
        displayScale: Double,
        purpose: ImageRequestPurpose
    ) -> ImageTargetPixelSize {
        guard pointWidth.isFinite,
              pointHeight.isFinite,
              displayScale.isFinite,
              pointWidth > 0,
              pointHeight > 0,
              displayScale > 0 else {
            return .default(for: purpose)
        }
        let scaledWidth = pointWidth * displayScale
        let scaledHeight = pointHeight * displayScale
        guard scaledWidth.isFinite,
              scaledHeight.isFinite,
              scaledWidth > 0,
              scaledHeight > 0 else {
            return .default(for: purpose)
        }
        return ImageTargetPixelSize(
            width: scaledWidth >= Double(maximumDimension)
                ? maximumDimension
                : Int(ceil(scaledWidth)),
            height: scaledHeight >= Double(maximumDimension)
                ? maximumDimension
                : Int(ceil(scaledHeight))
        )
    }

    static func `default`(
        for purpose: ImageRequestPurpose
    ) -> ImageTargetPixelSize {
        switch purpose {
        case .avatar:
            ImageTargetPixelSize(width: 384, height: 384)
        case .fixture:
            ImageTargetPixelSize(width: 1_024, height: 1_024)
        case .listThumbnail:
            ImageTargetPixelSize(width: 1_200, height: 1_200)
        case .mediaViewer:
            ImageTargetPixelSize(width: 4_096, height: 4_096)
        case .threadContent:
            ImageTargetPixelSize(width: 2_048, height: 4_096)
        }
    }
}

struct ImageResourceDescriptor: Equatable, Hashable, Sendable {
    private static let maximumResourceIDLength = 512
    private static let maximumURLLength = 2_048

    let resourceID: String
    let candidateURLs: [String]

    init(resourceID: String, candidateURLs: [String] = []) {
        let trimmedID = resourceID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        self.resourceID = trimmedID.utf8.count <= Self.maximumResourceIDLength
            ? trimmedID
            : ""
        var seen: Set<String> = []
        self.candidateURLs = candidateURLs.compactMap { rawValue in
            let trimmed = rawValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard trimmed.utf8.count <= Self.maximumURLLength,
                  let components = URLComponents(string: trimmed),
                  components.scheme?.lowercased() == "https",
                  components.host?.isEmpty == false,
                  components.user == nil,
                  components.password == nil,
                  components.fragment == nil,
                  let url = components.url,
                  url.absoluteURL == url,
                  seen.insert(url.absoluteString).inserted else {
                return nil
            }
            return url.absoluteString
        }
    }

    var isNetworkLoadable: Bool {
        !resourceID.isEmpty && !candidateURLs.isEmpty
    }
}

struct ImageRequest: Hashable, Sendable {
    let resourceID: String
    let candidateURLs: [String]
    let targetPixelSize: ImageTargetPixelSize
    let purpose: ImageRequestPurpose
    let resizeMode: ImageResizeMode

    init(
        resourceID: String,
        candidateURLs: [String] = [],
        targetPixelSize: ImageTargetPixelSize = .default(for: .fixture),
        purpose: ImageRequestPurpose = .fixture,
        resizeMode: ImageResizeMode = .fit
    ) {
        self.resourceID = resourceID
        self.candidateURLs = candidateURLs
        self.targetPixelSize = targetPixelSize
        self.purpose = purpose
        self.resizeMode = resizeMode
    }

    init(
        resource: ImageResourceDescriptor,
        targetPixelSize: ImageTargetPixelSize,
        purpose: ImageRequestPurpose,
        resizeMode: ImageResizeMode
    ) {
        self.init(
            resourceID: resource.resourceID,
            candidateURLs: resource.candidateURLs,
            targetPixelSize: targetPixelSize,
            purpose: purpose,
            resizeMode: resizeMode
        )
    }

    var stableCacheKey: String {
        let fingerprint = candidateURLs.reduce(
            UInt64(14_695_981_039_346_656_037)
        ) { partial, candidate in
            let candidateHash = candidate.utf8.reduce(partial) { value, byte in
                (value ^ UInt64(byte)) &* 1_099_511_628_211
            }
            return (candidateHash ^ 0xFF) &* 1_099_511_628_211
        }
        return [
            "image-v1",
            resourceID,
            purpose.rawValue,
            resizeMode.rawValue,
            "\(targetPixelSize.width)x\(targetPixelSize.height)",
            String(fingerprint, radix: 16)
        ].joined(separator: ":")
    }
}

struct ImagePayload: Sendable {
    let data: Data
    let mediaType: String
    let decodedImage: UIImage?
    let pixelSize: ImageTargetPixelSize?

    init(data: Data, mediaType: String) {
        self.data = data
        self.mediaType = mediaType
        decodedImage = nil
        pixelSize = nil
    }

    init(
        decodedImage: UIImage,
        mediaType: String,
        pixelSize: ImageTargetPixelSize
    ) {
        data = Data()
        self.mediaType = mediaType
        self.decodedImage = decodedImage
        self.pixelSize = pixelSize
    }

    @MainActor
    func displayImage() -> UIImage? {
        if let decodedImage {
            return decodedImage
        }
        return UIImage(data: data)?.preparingForDisplay()
    }
}

enum ImageLoadingError: Error, Equatable, Sendable {
    case decodingFailed
    case httpStatus(Int)
    case invalidCandidate
    case invalidMIME
    case invalidRequest
    case missingFixture
    case responseTooLarge(limit: Int)
    case sourceDimensionsTooLarge
    case transport
    case unavailable

    var safeDescription: String {
        switch self {
        case .decodingFailed:
            "decode"
        case let .httpStatus(status):
            "http-\(status)"
        case .invalidCandidate:
            "invalid-candidate"
        case .invalidMIME:
            "invalid-mime"
        case .invalidRequest:
            "invalid-request"
        case .missingFixture:
            "missing-fixture"
        case let .responseTooLarge(limit):
            "response-too-large-\(limit)"
        case .sourceDimensionsTooLarge:
            "source-dimensions-too-large"
        case .transport:
            "transport"
        case .unavailable:
            "unavailable"
        }
    }
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
