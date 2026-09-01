import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if TEST_SUPPORT
@testable import TiebaLite

enum TestImageFixtureFactory {
    static func png(width: Int, height: Int) throws -> Data {
        let image = try image(width: width, height: height)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw FixtureReadingRepositoryError.unavailable
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureReadingRepositoryError.unavailable
        }
        return data as Data
    }

    static func exifRotatedJPEG(width: Int, height: Int) throws -> Data {
        let image = try image(width: width, height: height)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw FixtureReadingRepositoryError.unavailable
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImagePropertyOrientation: 6] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureReadingRepositoryError.unavailable
        }
        return data as Data
    }

    private static func image(width: Int, height: Int) throws -> CGImage {
        guard width > 0,
              height > 0,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw FixtureReadingRepositoryError.unavailable
        }
        context.setFillColor(
            CGColor(
                colorSpace: colorSpace,
                components: [0.18, 0.42, 0.72, 1]
            ) ?? CGColor(gray: 0.5, alpha: 1)
        )
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            throw FixtureReadingRepositoryError.unavailable
        }
        return image
    }
}
#endif
