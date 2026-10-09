import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Photo import owns files, not a second image cache. ImageIO work stays off the main actor.
actor ComposerPhotoPreparation {
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
        if CGImageSourceGetType(source) as String? == UTType.gif.identifier {
            guard size < ComposerGIFData.byteLimit else { throw ImageUploadFailure.tooLarge }
            let bytes = try Data(contentsOf: file.url)
            try ComposerGIFData.validate(bytes, width: width, height: height)
            try Task.checkCancellation()
            return try save(bytes, width: width, height: height, extension: "gif")
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
            return try save(bytes as Data, width: image.width, height: image.height, extension: "jpg")
        }
        throw ImageUploadFailure.tooLarge
    }

    private func save(_ data: Data, width: Int, height: Int, extension suffix: String) throws -> ComposerPhoto {
        try Task.checkCancellation()
        let id = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("composer-\(UUID().uuidString).\(suffix)")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        return ComposerPhoto(id: id, file: ComposerPhotoFile(url: url), width: width, height: height, byteCount: data.count)
    }
}
