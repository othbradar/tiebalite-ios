import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Photo import owns files, not a second image cache. ImageIO work stays off the main actor.
actor ComposerPhotoPreparation {
    static let shared = ComposerPhotoPreparation()

    func prepare(file: ComposerPhotoFile) throws -> ComposerPhoto {
        try Task.checkCancellation()
        let size = try file.url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 50 * 1_024 * 1_024 else { throw ImageUploadFailure.tooLarge }
        guard let source = CGImageSourceCreateWithURL(file.url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, Int64(width) * Int64(height) <= 120_000_000 else {
            throw ImageUploadFailure.invalidImage
        }
        for maximum in [2_560, 1_920, 1_080] {
            try Task.checkCancellation()
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maximum]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw ImageUploadFailure.invalidImage
            }
            let bytes = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw ImageUploadFailure.invalidImage
            }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw ImageUploadFailure.invalidImage }
            guard bytes.length <= 5_242_880 else { continue }
            let data = bytes as Data
            let id = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("composer-\(UUID().uuidString).jpg")
            try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            return ComposerPhoto(id: id, file: ComposerPhotoFile(url: url), width: image.width,
                                 height: image.height, byteCount: data.count)
        }
        throw ImageUploadFailure.tooLarge
    }
}
