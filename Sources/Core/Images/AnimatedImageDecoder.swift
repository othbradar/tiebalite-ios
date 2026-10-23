import Foundation
import ImageIO
import Synchronization
import UIKit

/// One playback owns one source, used only under a lock on the existing image workers.
/// No decoded frame collection is retained. Cancellation never locks a decoding worker from UI.
final class AnimatedImageDecoder: Sendable {
    private struct Storage { var source: CGImageSource? }
    private let storage = Mutex(Storage())
    private let resource: AnimatedImageResource
    init(resource: AnimatedImageResource) { self.resource = resource }

    func frame(at index: Int, maximumDimension: Int) async throws -> AnimatedImageFrame {
        try await ImageDecodeExecutor.run { [self] in
            try storage.withLock { state in
                guard (0..<resource.frameCount).contains(index) else { throw ImageLoadingError.decodingFailed }
                if state.source == nil {
                    state.source = CGImageSourceCreateWithData(resource.data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
                    #if UITESTING
                    ScrollWorkMetrics.count("gif.source")
                    #endif
                }
                guard let source = state.source else { throw ImageLoadingError.decodingFailed }
                defer { CGImageSourceRemoveCacheAtIndex(source, index) }
                guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: min(1_024, max(1, maximumDimension))
                ] as CFDictionary) else { throw ImageLoadingError.decodingFailed }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let timing = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                ?? properties?[kCGImagePropertyWebPDictionary] as? [CFString: Any]
            let delay = timing?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
                ?? timing?[kCGImagePropertyWebPUnclampedDelayTime] as? NSNumber
                ?? timing?[kCGImagePropertyGIFDelayTime] as? NSNumber
                ?? timing?[kCGImagePropertyWebPDelayTime] as? NSNumber
            let seconds = delay?.doubleValue ?? 0.1
            return AnimatedImageFrame(image: UIImage(cgImage: image), delay: seconds >= 0.02 ? seconds : 0.1)
            }
        }
    }
}
