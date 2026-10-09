import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Native iOS GIF uploads retain their encoded frames; they never use the JPEG preparation path.
enum ComposerGIFData {
    static let byteLimit = 10 * 1_024 * 1_024 // Native upload rejects equality as well as larger files.

    static func hasHeader(_ bytes: Data) -> Bool {
        bytes.starts(with: Data("GIF87a".utf8)) || bytes.starts(with: Data("GIF89a".utf8))
    }

    static func validate(_ bytes: Data, width: Int, height: Int) throws {
        guard !bytes.isEmpty, bytes.count < byteLimit else { throw ImageUploadFailure.tooLarge }
        guard hasHeader(bytes),
              let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetType(source) as String? == UTType.gif.identifier,
              CGImageSourceGetStatus(source) == .statusComplete, CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              properties[kCGImagePropertyPixelWidth] as? Int == width,
              properties[kCGImagePropertyPixelHeight] as? Int == height else {
            throw ImageUploadFailure.invalidImage
        }
    }
}
