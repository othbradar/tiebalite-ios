import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageResourceDiagnostics: Sendable {
    let diskHits: Int
    let networkRequests: Int
    let merged: Int
    let diskBytes: Int
}

/// Anonymous encoded resources only. A complete URL (including query) is the resource/version identity.
actor ImageResourceStore: HTTPDataLoading {
    static let shared = ImageResourceStore(
        loader: URLSessionDataLoader(configuration: URLSessionHTTPClient.makeEphemeralConfiguration()),
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TiebaLiteImages-v1", isDirectory: true))

    private let loader: any HTTPDataLoading
    private let disk: ImageDiskCache?
    private let policy: ImageCachePolicy
    private let downloads = ImageWorkPool<EncodedImageResource>(limit: 4)
    private(set) var epoch: UInt64 = 0
    private var diskHits = 0
    private var networkRequests = 0
    private var isClearing = false

    init(loader: any HTTPDataLoading, directory: URL?, policy: ImageCachePolicy = .init()) {
        self.loader = loader
        self.policy = policy
        disk = directory.map { ImageDiskCache(directory: $0, policy: policy) }
    }

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        guard !isClearing else { throw CancellationError() }
        guard let url = request.url, request.httpMethod == "GET", request.httpBody == nil,
              request.value(forHTTPHeaderField: "Authorization") == nil,
              request.value(forHTTPHeaderField: "Cookie") == nil else { throw ImageLoadingError.invalidRequest }
        let ticket = epoch
        let key = ImageDiskCache.digest(Data(("encoded-v1|anonymous|" + url.absoluteString).utf8))
        let resource = try await downloads.value(for: "\(ticket)|\(key)", foreground: Task.currentPriority != .utility) {
            try await self.readOrDownload(request, key: key, epoch: ticket)
        }
        try Task.checkCancellation()
        guard ticket == epoch else { throw CancellationError() }
        guard resource.data.count <= maximumByteCount else { throw HTTPClientError.responseTooLarge(limit: maximumByteCount) }
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                             headerFields: ["Content-Type": resource.mimeType]) else { throw ImageLoadingError.transport }
        return (resource.data, response)
    }

    func clear() async {
        isClearing = true
        epoch &+= 1
        await downloads.cancelAll()
        await disk?.clear(epoch: epoch)
        isClearing = false
    }

    func diagnostics() async -> ImageResourceDiagnostics {
        ImageResourceDiagnostics(diskHits: diskHits, networkRequests: networkRequests,
                                 merged: await downloads.merged, diskBytes: await disk?.byteCount() ?? 0)
    }

    private func readOrDownload(_ request: URLRequest, key: String, epoch ticket: UInt64) async throws -> EncodedImageResource {
        let persistent = Self.permitsPersistence(request.url)
        if persistent, let resource = await disk?.read(key) {
            guard ticket == epoch else { throw CancellationError() }
            diskHits += 1
            return resource
        }
        try Task.checkCancellation()
        guard ticket == epoch else { throw CancellationError() }
        var anonymous = request
        anonymous.httpShouldHandleCookies = false
        anonymous.cachePolicy = .reloadIgnoringLocalCacheData
        networkRequests += 1
        let (data, response) = try await loader.data(for: anonymous, maximumByteCount: policy.maximumResourceBytes)
        try Task.checkCancellation()
        guard ticket == epoch else { throw CancellationError() }
        guard let response = response as? HTTPURLResponse else { throw ImageLoadingError.transport }
        guard (200..<300).contains(response.statusCode) else { throw ImageLoadingError.httpStatus(response.statusCode) }
        if let mime = response.mimeType, !mime.lowercased().hasPrefix("image/") { throw ImageLoadingError.invalidMIME }
        guard data.count <= policy.maximumResourceBytes else {
            throw ImageLoadingError.responseTooLarge(limit: policy.maximumResourceBytes)
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete, CGImageSourceGetCount(source) > 0,
              let identifier = CGImageSourceGetType(source), let type = UTType(identifier as String), type.conforms(to: .image) else {
            throw ImageLoadingError.decodingFailed
        }
        let resource = EncodedImageResource(data: data, mimeType: type.preferredMIMEType ?? "image/unknown")
        let control = response.value(forHTTPHeaderField: "Cache-Control")?.lowercased() ?? ""
        if persistent, !control.contains("no-store"), !control.contains("private") {
            await disk?.write(resource, key: key, epoch: ticket)
        }
        guard ticket == epoch else { throw CancellationError() }
        return resource
    }

    nonisolated static func permitsPersistence(_ url: URL?) -> Bool {
        guard let url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let publicHosts: Set<String> = ["imgsrc.baidu.com", "imgsa.baidu.com", "tiebapic.baidu.com", "tb.himg.baidu.com"]
        guard let host = parts.host?.lowercased(), publicHosts.contains(host),
              parts.scheme == "https" || LegacyPortraitURL.permits(parts),
              parts.user == nil, parts.password == nil, parts.fragment == nil else { return false }
        // Unknown signed/private candidates remain transient; never remove query fields to force a cache hit.
        let sensitive = ["token", "sign", "auth", "cookie", "credential", "expires", "bduss", "stoken", "secret", "session", "key"]
        return !(parts.queryItems ?? []).contains { item in sensitive.contains { item.name.lowercased().contains($0) } }
    }
}
