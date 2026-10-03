import CryptoKit
import Foundation

struct ImageCachePolicy: Sendable {
    var diskBytes = 512 * 1_024 * 1_024
    var maximumResourceBytes = 24 * 1_024 * 1_024
    var maximumEntries = 4_096
    static let highDefinitionSize = ImageTargetPixelSize(width: 4_096, height: 4_096)
}

struct EncodedImageResource: Codable, Sendable {
    let data: Data
    let mimeType: String
}

/// Lazy, bounded metadata loading and all file I/O stay off the main actor. No image decoding or directory scan on launch.
actor ImageDiskCache {
    private struct Entry: Codable {
        let bytes: Int
        let checksum: String
        var access: Date
    }

    private let directory: URL
    private let policy: ImageCachePolicy
    private var index: [String: Entry] = [:]
    private var prepared = false
    private var epoch: UInt64 = 0

    init(directory: URL, policy: ImageCachePolicy = .init()) {
        self.directory = directory
        self.policy = policy
    }

    nonisolated static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func read(_ key: String) -> EncodedImageResource? {
        prepare()
        guard let entry = index[key] else { return nil }
        guard let size = try? file(key).resourceValues(forKeys: [.fileSizeKey]).fileSize, size == entry.bytes,
              let bytes = try? Data(contentsOf: file(key)), Self.digest(bytes) == entry.checksum,
              let resource = try? PropertyListDecoder().decode(EncodedImageResource.self, from: bytes),
              resource.data.count <= policy.maximumResourceBytes else {
            remove(key)
            return nil
        }
        index[key]?.access = Date()
        try? saveIndex()
        return resource
    }

    func write(_ resource: EncodedImageResource, key: String, epoch ticket: UInt64) {
        prepare()
        guard epoch == ticket, resource.data.count <= policy.maximumResourceBytes,
              let bytes = try? PropertyListEncoder().encode(resource), bytes.count <= policy.diskBytes else { return }
        do {
            index[key] = Entry(bytes: bytes.count, checksum: Self.digest(bytes), access: Date())
            evict()
            // Record intent first: a killed process may leave a missing file, never an unbounded orphan image.
            try saveIndex()
            try bytes.write(to: file(key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            remove(key) // A disk failure must not turn a successful download into a display failure.
        }
    }

    func clear(epoch: UInt64) {
        self.epoch = epoch
        prepare()
        for key in Array(index.keys) { remove(key, save: false) }
        try? saveIndex()
    }

    func byteCount() -> Int {
        prepare()
        return index.values.reduce(0) { $0 + $1.bytes }
    }

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("index-v1.plist")
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 2 * 1_024 * 1_024,
           let bytes = try? Data(contentsOf: url),
           let saved = try? PropertyListDecoder().decode([String: Entry].self, from: bytes) {
            index = saved.filter {
                $0.key.count == 64 && $0.key.allSatisfy(\.isHexDigit) && $0.value.bytes > 0
                    && $0.value.bytes <= policy.maximumResourceBytes + 4_096
            }
            evict()
        } else if FileManager.default.fileExists(atPath: directory.path) {
            // An unreadable index has no trustworthy ownership list. Reset only this version's image directory.
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func evict() {
        var total = index.values.reduce(0) { $0 + $1.bytes }
        for (key, entry) in index.sorted(by: { $0.value.access < $1.value.access }) {
            guard total > policy.diskBytes || index.count > policy.maximumEntries else { break }
            total -= entry.bytes
            remove(key, save: false)
        }
    }

    private func remove(_ key: String, save: Bool = true) {
        index[key] = nil
        try? FileManager.default.removeItem(at: file(key))
        if save { try? saveIndex() }
    }

    private func file(_ key: String) -> URL { directory.appendingPathComponent(key).appendingPathExtension("image") }

    private func saveIndex() throws {
        try PropertyListEncoder().encode(index).write(to: directory.appendingPathComponent("index-v1.plist"), options: .atomic)
    }
}
