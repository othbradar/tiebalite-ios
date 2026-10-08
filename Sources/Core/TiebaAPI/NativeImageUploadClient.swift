import CryptoKit
import Foundation

@MainActor
struct NativeImageUploadClient {
    let client: any HTTPClient
    let validateAuthorization: () throws -> Void
    let makeRequest: (ComposerPhoto, Int, Bool, Data) throws -> HTTPRequest

    func upload(_ photo: ComposerPhoto, progress: @escaping @Sendable (Double) async -> Void) async throws -> UploadedComposerPhoto {
        try validateAuthorization()
        let data = try await NativeUploadFileReader().read(photo)
        let total = (data.count + NativeImageUploadProtocol.chunkSize - 1) / NativeImageUploadProtocol.chunkSize
        for chunk in 1...total {
            try Task.checkCancellation()
            try validateAuthorization()
            let start = (chunk - 1) * NativeImageUploadProtocol.chunkSize
            let end = min(start + NativeImageUploadProtocol.chunkSize, data.count)
            let response = try await client.execute(makeRequest(photo, chunk, chunk == total, data.subdata(in: start..<end)))
            try Task.checkCancellation()
            try validateAuthorization()
            let result = try NativeImageUploadProtocol.decode(response, final: chunk == total)
            await progress(Double(end) / Double(data.count))
            try Task.checkCancellation()
            try validateAuthorization()
            if let result { return result }
        }
        throw ImageUploadFailure.malformedResponse
    }
}

private actor NativeUploadFileReader {
    func read(_ photo: ComposerPhoto) throws -> Data {
        try Task.checkCancellation()
        guard photo.byteCount > 0, photo.byteCount <= 5_242_880, photo.width > 0, photo.height > 0,
              try photo.file.url.resourceValues(forKeys: [.fileSizeKey]).fileSize == photo.byteCount else {
            throw ImageUploadFailure.invalidImage
        }
        let bytes = try Data(contentsOf: photo.file.url)
        guard bytes.count == photo.byteCount, bytes.starts(with: [0xff, 0xd8, 0xff]),
              Insecure.MD5.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == photo.id else {
            throw ImageUploadFailure.invalidImage
        }
        try Task.checkCancellation()
        return bytes
    }
}
