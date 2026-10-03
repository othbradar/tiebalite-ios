import Foundation
import ImageIO
import UniformTypeIdentifiers

/// No bitmap decode, display cache, authentication, or persistent image cache.
actor OriginalImageFileFetcher: ImageFileFetching {
    private let loader: any HTTPDataLoading
    private let maximumByteCount: Int

    init(loader: any HTTPDataLoading, maximumByteCount: Int = 24 * 1_024 * 1_024) {
        self.loader = loader
        self.maximumByteCount = maximumByteCount
    }

    static func production() -> OriginalImageFileFetcher {
        OriginalImageFileFetcher(loader: URLSessionDataLoader(
            configuration: URLSessionHTTPClient.makeEphemeralConfiguration()))
    }

    func fetch(_ request: ImageExportRequest) async throws -> ImageExportFile {
        let ordered = request.descriptor.imageRequest(
            purpose: .mediaViewer, targetPixelSize: .init(width: 1, height: 1)
        ).candidateURLs.compactMap(URL.init(string:))
        for candidate in ordered where candidate.scheme?.lowercased() == "https" {
            try Task.checkCancellation()
            let downloaded: Data
            let type: UTType
            do {
                var networkRequest = URLRequest(url: candidate, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
                networkRequest.httpMethod = "GET"
                networkRequest.httpShouldHandleCookies = false
                let (bytes, response) = try await loader.data(for: networkRequest, maximumByteCount: maximumByteCount)
                try Task.checkCancellation()
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode), bytes.count <= maximumByteCount,
                      let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                      CGImageSourceGetCount(source) > 0,
                      CGImageSourceGetStatus(source) == .statusComplete,
                      let identifier = CGImageSourceGetType(source),
                      let detected = UTType(identifier as String), detected.conforms(to: .image) else {
                    throw ImageExportFailure.download
                }
                downloaded = bytes
                type = detected
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try Task.checkCancellation()
                continue
            }
            let isOriginal = request.descriptor.candidates.contains {
                $0.role == .original && $0.destination.absoluteString == candidate.absoluteString
            }
            return try writeTemporaryFile(downloaded, type: type, request: request, isOriginal: isOriginal)
        }
        throw ImageExportFailure.download
    }

    func remove(_ file: ImageExportFile) {
        // This directory belongs solely to this export; display/cache files are never touched.
        try? FileManager.default.removeItem(at: file.directory)
    }

    private func writeTemporaryFile(
        _ bytes: Data, type: UTType, request: ImageExportRequest, isOriginal: Bool
    ) throws -> ImageExportFile {
        let directory: URL
        do {
            directory = try FileManager.default.url(
                for: .itemReplacementDirectory, in: .userDomainMask,
                appropriateFor: FileManager.default.temporaryDirectory, create: true)
        } catch { throw ImageExportFailure.filePreparation }
        let url = directory.appendingPathComponent("TiebaLite-image").appendingPathExtension(type.preferredFilenameExtension ?? "img")
        do {
            try bytes.write(to: url, options: .atomic)
            try Task.checkCancellation()
            return ImageExportFile(request: request, url: url, directory: directory,
                                   typeIdentifier: type.identifier, isOriginal: isOriginal)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            if error is CancellationError { throw CancellationError() }
            throw ImageExportFailure.filePreparation
        }
    }
}
