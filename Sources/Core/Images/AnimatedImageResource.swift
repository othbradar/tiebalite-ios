import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Bounded encoded bytes, not a UIImage containing every decoded frame.
struct AnimatedImageResource: Sendable {
    static let byteLimit = 8 * 1_024 * 1_024
    static let pixelLimit = 4_000_000
    static let frameLimit = 500
    let data: Data
    let id: String
    let frameCount: Int
    let loopCount: Int

    static func inspect(data: Data, byteLimit: Int = byteLimit,
                        pixelLimit: Int = pixelLimit, frameLimit: Int = frameLimit) -> Self? {
        guard data.count <= byteLimit,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source), [UTType.gif.identifier, UTType.webP.identifier].contains(type as String)
        else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1, count <= frameLimit,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue * height.doubleValue <= Double(pixelLimit) else { return nil }
        let root = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        let sequence = root?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            ?? root?[kCGImagePropertyWebPDictionary] as? [CFString: Any]
        let loops = sequence?[kCGImagePropertyGIFLoopCount] as? NSNumber
            ?? sequence?[kCGImagePropertyWebPLoopCount] as? NSNumber
        return Self(data: data, id: ImageDiskCache.digest(data), frameCount: count, loopCount: max(0, loops?.intValue ?? 0))
    }

    func frame(at index: Int, maximumDimension: Int) async throws -> AnimatedImageFrame {
        try await AnimatedImageDecoder(resource: self).frame(at: index, maximumDimension: maximumDimension)
    }

}

struct AnimatedImageFrame: Sendable {
    let image: UIImage
    let delay: Double
}
