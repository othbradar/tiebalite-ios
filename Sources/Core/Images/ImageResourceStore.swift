import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageResourceDiagnostics: Sendable {
    let diskHits: Int
    let networkRequests: Int
    let merged: Int
    let diskBytes: Int
    var pendingWriteBytes = 0
    var pendingWrites = 0
    var committedWrites = 0
    var skippedWrites = 0
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
    private let flights = ImageWorkPool<EncodedImageResource>(limit: nil)
    private let diskReads = ImageWorkPool<EncodedImageResource?>(limit: 2)
    private struct PendingWrite {
        let key: String
        let epoch: UInt64
        let resource: EncodedImageResource
    }
    private var queuedWrites: [PendingWrite] = []
    private var activeWrite: PendingWrite?
    private var writer: Task<Void, Never>?
    private var skippedWrites = 0
    private(set) var epoch: UInt64 = 0
    private var diskHits = 0
    private var networkRequests = 0
    private var isClearing = false

    init(loader: any HTTPDataLoading, directory: URL?, policy: ImageCachePolicy = .init(),
         beforeDiskWrite: (@Sendable () async -> Void)? = nil) {
        self.loader = loader
        self.policy = policy
        disk = directory.map { ImageDiskCache(directory: $0, policy: policy, beforeWrite: beforeDiskWrite) }
    }

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        guard !isClearing else { throw CancellationError() }
        guard let url = request.url, request.httpMethod == "GET", request.httpBody == nil,
              request.value(forHTTPHeaderField: "Authorization") == nil,
              request.value(forHTTPHeaderField: "Cookie") == nil else { throw ImageLoadingError.invalidRequest }
        let ticket = epoch
        let key = ImageDiskCache.digest(Data(("encoded-v1|anonymous|" + url.absoluteString).utf8))
        let resource = try await flights.value(for: "\(ticket)|\(key)", foreground: Task.currentPriority != .utility) {
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
        let ticket = epoch
        queuedWrites.removeAll()
        await flights.cancelAll()
        await diskReads.cancelAll()
        await downloads.cancelAll()
        await disk?.clear(epoch: epoch)
        if ticket == epoch { isClearing = false }
    }

    func diagnostics() async -> ImageResourceDiagnostics {
        ImageResourceDiagnostics(diskHits: diskHits, networkRequests: networkRequests,
                                 merged: await flights.merged, diskBytes: await disk?.byteCount() ?? 0,
                                 pendingWriteBytes: pendingWriteBytes, pendingWrites: queuedWrites.count + (activeWrite == nil ? 0 : 1),
                                 committedWrites: await disk?.committedWrites ?? 0, skippedWrites: skippedWrites)
    }

    func downloadCounts() async -> ImageWorkPool<EncodedImageResource>.Counts { await downloads.counts }

    private func readOrDownload(_ request: URLRequest, key: String, epoch ticket: UInt64) async throws -> EncodedImageResource {
        let persistent = Self.permitsPersistence(request.url)
        if let pending = pendingResource(key, epoch: ticket) { return pending }
        let flightKey = "\(ticket)|\(key)"
        let priority = await flights.priority(for: flightKey)
        let disk = disk
        if persistent, let resource = try await diskReads.value(for: flightKey, foreground: false, sharedPriority: priority,
                                                                operation: { await disk?.read(key) }) {
            guard ticket == epoch else { throw CancellationError() }
            diskHits += 1
            return resource
        }
        try Task.checkCancellation()
        guard ticket == epoch else { throw CancellationError() }
        return try await downloads.value(for: flightKey, foreground: false, sharedPriority: priority) {
            try await self.download(request, key: key, epoch: ticket, persistent: persistent)
        }
    }

    private func download(_ request: URLRequest, key: String, epoch ticket: UInt64,
                          persistent: Bool) async throws -> EncodedImageResource {
        try Task.checkCancellation()
        guard ticket == epoch else { throw CancellationError() }
        // Recheck completed, pending persistence at admission. The resource flight
        // owns the entire lookup/download and cancelled downloads cannot publish bytes.
        if let pending = pendingResource(key, epoch: ticket) { return pending }
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
            enqueueWrite(resource, key: key, epoch: ticket)
        }
        guard ticket == epoch else { throw CancellationError() }
        return resource
    }

    /// Explicit persistence barrier; displaying bytes is not proof of an offline cache commit.
    func flushPersistence() async {
        await writer?.value
        await disk?.flushMaintenance()
    }

    private var pendingWriteBytes: Int {
        queuedWrites.reduce(activeWrite?.resource.data.count ?? 0) { $0 + $1.resource.data.count }
    }

    private func pendingResource(_ key: String, epoch ticket: UInt64) -> EncodedImageResource? {
        if let activeWrite, activeWrite.key == key, activeWrite.epoch == ticket { return activeWrite.resource }
        return queuedWrites.first { $0.key == key && $0.epoch == ticket }?.resource
    }

    private func enqueueWrite(_ resource: EncodedImageResource, key: String, epoch ticket: UInt64) {
        guard disk != nil, ticket == epoch, pendingResource(key, epoch: ticket) == nil else { return }
        // Include the active write (even across clear) in the bound. Overflow skips
        // this optional persistence; it never delays a valid image or retains more Data.
        guard queuedWrites.count + (activeWrite == nil ? 0 : 1) < 2,
              pendingWriteBytes + resource.data.count <= 2 * policy.maximumResourceBytes else {
            skippedWrites += 1
            return
        }
        queuedWrites.append(.init(key: key, epoch: ticket, resource: resource))
        guard writer == nil else { return }
        writer = Task { await self.drainWrites() }
    }

    private func drainWrites() async {
        while !queuedWrites.isEmpty {
            let next = queuedWrites.removeFirst()
            activeWrite = next
            await disk?.write(next.resource, key: next.key, epoch: next.epoch)
            activeWrite = nil
        }
        writer = nil
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
