import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

actor ProductionImageLoader: ImageLoading {
    static let defaultResponseByteLimit = 24 * 1_024 * 1_024
    static let defaultMemoryCostLimit = 96 * 1_024 * 1_024
    static let defaultSourcePixelLimit: UInt64 = 120_000_000

    private final class CachedImage {
        let image: UIImage
        let mediaType: String
        let pixelSize: ImageTargetPixelSize

        init(
            image: UIImage,
            mediaType: String,
            pixelSize: ImageTargetPixelSize
        ) {
            self.image = image
            self.mediaType = mediaType
            self.pixelSize = pixelSize
        }
    }

    private struct SourcePixelSize {
        let width: Int
        let height: Int
    }

    private let loader: any HTTPDataLoading
    private let responseByteLimit: Int
    private let sourcePixelLimit: UInt64
    private let cache: NSCache<NSString, CachedImage>
    private var memoryWarningTask: Task<Void, Never>?

    init(
        loader: any HTTPDataLoading,
        responseByteLimit: Int = defaultResponseByteLimit,
        memoryCostLimit: Int = defaultMemoryCostLimit,
        sourcePixelLimit: UInt64 = defaultSourcePixelLimit
    ) {
        self.loader = loader
        self.responseByteLimit = max(1, responseByteLimit)
        self.sourcePixelLimit = max(1, sourcePixelLimit)
        let cache = NSCache<NSString, CachedImage>()
        cache.totalCostLimit = max(1, memoryCostLimit)
        cache.countLimit = 256
        self.cache = cache
        memoryWarningTask = nil
    }

    deinit {
        memoryWarningTask?.cancel()
    }

    static func production() -> ProductionImageLoader {
        let imageLoader = ProductionImageLoader(
            loader: URLSessionDataLoader(
                configuration: makeURLSessionConfiguration()
            )
        )
        Task {
            await imageLoader.startMemoryWarningObservation()
        }
        return imageLoader
    }

    nonisolated static func makeURLSessionConfiguration()
        -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1_024 * 1_024,
            diskCapacity: 0
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.waitsForConnectivity = false
        return configuration
    }

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        try Task.checkCancellation()
        guard !request.resourceID.isEmpty,
              !request.candidateURLs.isEmpty else {
            throw ImageLoadingError.invalidRequest
        }
        let key = request.stableCacheKey as NSString
        if let cached = cache.object(forKey: key) {
            return ImagePayload(
                decodedImage: cached.image,
                mediaType: cached.mediaType,
                pixelSize: cached.pixelSize
            )
        }

        var lastFailure: ImageLoadingError = .invalidCandidate
        var seen: Set<URL> = []
        for rawCandidate in request.candidateURLs {
            try Task.checkCancellation()
            guard let candidate = Self.validatedCandidate(rawCandidate),
                  seen.insert(candidate).inserted else {
                lastFailure = .invalidCandidate
                continue
            }
            do {
                let decoded = try await loadCandidate(
                    candidate,
                    request: request
                )
                try Task.checkCancellation()
                cache.setObject(
                    decoded,
                    forKey: key,
                    cost: Self.memoryCost(of: decoded.image)
                )
                return ImagePayload(
                    decodedImage: decoded.image,
                    mediaType: decoded.mediaType,
                    pixelSize: decoded.pixelSize
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch let failure as ImageLoadingError {
                lastFailure = failure
            } catch let failure as HTTPClientError {
                if case let .responseTooLarge(limit) = failure {
                    lastFailure = .responseTooLarge(limit: limit)
                } else {
                    lastFailure = .transport
                }
            } catch let failure as URLError where failure.code == .cancelled {
                throw CancellationError()
            } catch {
                lastFailure = .transport
            }
        }
        try Task.checkCancellation()
        throw lastFailure
    }

    func removeAllCachedImages() {
        cache.removeAllObjects()
    }

    private func startMemoryWarningObservation() {
        guard memoryWarningTask == nil else {
            return
        }
        memoryWarningTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: UIApplication.didReceiveMemoryWarningNotification
            ) {
                guard !Task.isCancelled else {
                    return
                }
                await self?.removeAllCachedImages()
            }
        }
    }

    private func loadCandidate(
        _ url: URL,
        request: ImageRequest
    ) async throws -> CachedImage {
        var urlRequest = URLRequest(
            url: url,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 30
        )
        urlRequest.httpMethod = "GET"
        urlRequest.httpShouldHandleCookies = false
        let (data, response) = try await loader.data(
            for: urlRequest,
            maximumByteCount: responseByteLimit
        )
        try Task.checkCancellation()
        guard data.count <= responseByteLimit else {
            throw ImageLoadingError.responseTooLarge(limit: responseByteLimit)
        }
        guard let response = response as? HTTPURLResponse else {
            throw ImageLoadingError.transport
        }
        guard (200...299).contains(response.statusCode) else {
            throw ImageLoadingError.httpStatus(response.statusCode)
        }
        let responseMIME = response.mimeType?.lowercased()
        if let responseMIME, !responseMIME.hasPrefix("image/") {
            throw ImageLoadingError.invalidMIME
        }
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else {
            throw ImageLoadingError.decodingFailed
        }
        let sourceSize = try sourcePixelSize(source)
        let thumbnailMaximum = Self.thumbnailMaximumDimension(
            source: sourceSize,
            target: request.targetPixelSize,
            resizeMode: request.resizeMode
        )
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaximum
        ]
        guard let downsampled = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw ImageLoadingError.decodingFailed
        }
        let decoded: CGImage
        switch request.resizeMode {
        case .fill:
            guard let cropped = Self.croppedToFill(
                downsampled,
                target: request.targetPixelSize
            ) else {
                throw ImageLoadingError.decodingFailed
            }
            decoded = cropped
        case .fit:
            decoded = downsampled
        }
        let pixelSize = ImageTargetPixelSize(
            width: decoded.width,
            height: decoded.height
        )
        let mediaType = responseMIME
            ?? CGImageSourceGetType(source)
                .flatMap { UTType($0 as String)?.preferredMIMEType }
            ?? "image/unknown"
        return CachedImage(
            image: UIImage(cgImage: decoded, scale: 1, orientation: .up),
            mediaType: mediaType,
            pixelSize: pixelSize
        )
    }

    private func sourcePixelSize(
        _ source: CGImageSource
    ) throws -> SourcePixelSize {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            nil
        ) as? [CFString: Any],
        let width = Self.integerProperty(
            properties[kCGImagePropertyPixelWidth]
        ),
        let height = Self.integerProperty(
            properties[kCGImagePropertyPixelHeight]
        ),
        width > 0,
        height > 0 else {
            throw ImageLoadingError.decodingFailed
        }
        let (pixelCount, overflow) = UInt64(width).multipliedReportingOverflow(
            by: UInt64(height)
        )
        guard !overflow, pixelCount <= sourcePixelLimit else {
            throw ImageLoadingError.sourceDimensionsTooLarge
        }
        let orientation = Self.integerProperty(
            properties[kCGImagePropertyOrientation]
        ) ?? 1
        if (5...8).contains(orientation) {
            return SourcePixelSize(width: height, height: width)
        }
        return SourcePixelSize(width: width, height: height)
    }

    nonisolated private static func thumbnailMaximumDimension(
        source: SourcePixelSize,
        target: ImageTargetPixelSize,
        resizeMode: ImageResizeMode
    ) -> Int {
        let widthRatio = Double(target.width) / Double(source.width)
        let heightRatio = Double(target.height) / Double(source.height)
        let requestedRatio: Double
        switch resizeMode {
        case .fill:
            requestedRatio = max(widthRatio, heightRatio)
        case .fit:
            requestedRatio = min(widthRatio, heightRatio)
        }
        let scale = min(1, max(0, requestedRatio))
        let sourceMaximum = max(source.width, source.height)
        return min(
            ImageTargetPixelSize.maximumDimension,
            max(1, Int(ceil(Double(sourceMaximum) * scale)))
        )
    }

    nonisolated private static func croppedToFill(
        _ image: CGImage,
        target: ImageTargetPixelSize
    ) -> CGImage? {
        let boundedWidth = min(image.width, target.width)
        let boundedHeight = min(image.height, target.height)
        guard boundedWidth > 0, boundedHeight > 0 else {
            return nil
        }
        let targetAspect = Double(target.width) / Double(target.height)
        let boundedAspect = Double(boundedWidth) / Double(boundedHeight)
        let cropWidth: Int
        let cropHeight: Int
        if boundedAspect > targetAspect {
            cropHeight = boundedHeight
            cropWidth = max(1, Int(floor(Double(cropHeight) * targetAspect)))
        } else {
            cropWidth = boundedWidth
            cropHeight = max(1, Int(floor(Double(cropWidth) / targetAspect)))
        }
        let cropRect = CGRect(
            x: (image.width - cropWidth) / 2,
            y: (image.height - cropHeight) / 2,
            width: cropWidth,
            height: cropHeight
        )
        return image.cropping(to: cropRect)
    }

    nonisolated private static func validatedCandidate(
        _ rawValue: String
    ) -> URL? {
        guard let components = URLComponents(string: rawValue),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              let url = components.url,
              url.absoluteURL == url else {
            return nil
        }
        return url
    }

    nonisolated private static func integerProperty(_ value: Any?) -> Int? {
        switch value {
        case let value as NSNumber:
            value.intValue
        case let value as Int:
            value
        default:
            nil
        }
    }

    nonisolated private static func memoryCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else {
            return 1
        }
        let (cost, overflow) = cgImage.bytesPerRow.multipliedReportingOverflow(
            by: cgImage.height
        )
        return overflow ? Int.max : max(1, cost)
    }
}
