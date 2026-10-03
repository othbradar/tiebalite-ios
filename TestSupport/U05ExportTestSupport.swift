import Foundation

#if TEST_SUPPORT
@testable import TiebaLite

actor ExportTestTransport: HTTPDataLoading {
    let bytes: Data
    private(set) var requests: [URLRequest] = []
    private var fails = false
    private var failOriginal = false

    init(bytes: Data) { self.bytes = bytes }
    func setFails(_ value: Bool) { fails = value }
    func setFailOriginal(_ value: Bool) { failOriginal = value }

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        requests.append(request)
        if fails || (failOriginal && request.url?.path.contains("original") == true) { throw ImageExportFailure.download }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                             headerFields: ["Content-Type": "image/jpeg"]) else {
            throw ImageExportFailure.download
        }
        return (bytes, response)
    }
}

actor ExportTestWriter: PhotoLibraryWriting {
    private(set) var authorizationCount = 0
    private(set) var writtenIDs: [String] = []
    private var urls: [URL] = []
    private var failure: ImageExportFailure?
    private let holdWrites: Bool
    private var completion: CheckedContinuation<Void, Never>?
    private var observers: [CheckedContinuation<Void, Never>] = []

    init(holdWrites: Bool) { self.holdWrites = holdWrites }
    func setFailure(_ value: ImageExportFailure?) { failure = value }

    func authorizeAddOnly() throws {
        authorizationCount += 1
        if failure == .permissionDenied { throw ImageExportFailure.permissionDenied }
    }

    func write(_ file: ImageExportFile) async throws {
        urls.append(file.url)
        writtenIDs.append(file.request.mediaID)
        if let failure { throw failure }
        if holdWrites {
            await withCheckedContinuation { continuation in
                completion = continuation
                observers.forEach { $0.resume() }
                observers.removeAll()
            }
        }
    }

    func waitForWrite() async {
        if completion != nil { return }
        await withCheckedContinuation { observers.append($0) }
    }

    func finishWrite() { completion?.resume(); completion = nil }
    var fileExistsDuringWrite: Bool { !urls.isEmpty && urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) } }
    var filesWereRemoved: Bool { urls.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) } }
}

@MainActor
struct ExportTestFixture {
    let bytes: Data
    let transport: ExportTestTransport
    let writer: ExportTestWriter

    init(holdWrites: Bool = false) throws {
        bytes = try TestImageFixtureFactory.png(width: 40, height: 20)
        transport = ExportTestTransport(bytes: bytes)
        writer = ExportTestWriter(holdWrites: holdWrites)
    }

    func store() -> MediaExportStore {
        MediaExportStore(fetcher: OriginalImageFileFetcher(loader: transport), writer: writer)
    }
}
#endif
