import Foundation

#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
/// Deterministic encoded PNG and a mock write endpoint; fixture launches never request Photos access.
struct HarnessExportImageTransport: HTTPDataLoading {
    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
              let bytes = Data(base64Encoded:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mNk+M8AAAICAQB7CY9eAAAAAElFTkSuQmCC") else {
            throw ImageExportFailure.download
        }
        return (bytes, response)
    }
}

struct HarnessExportPhotoWriter: PhotoLibraryWriting {
    func authorizeAddOnly() throws { try Task.checkCancellation() }
    func write(_ file: ImageExportFile) throws {
        try Task.checkCancellation()
        guard FileManager.default.fileExists(atPath: file.url.path) else { throw ImageExportFailure.write }
    }
}
#endif
