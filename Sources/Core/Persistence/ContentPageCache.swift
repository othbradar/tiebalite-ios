import CryptoKit
import Foundation

/// Small bounded byte store. Disk operations run on a separate actor so clearing can invalidate
/// foreground tickets immediately while a bounded file read/write is in progress.
actor ContentPageCache {
    private struct MemoryEntry {
        let data: Data
        var access: UInt64
    }

    private(set) var memoryHits = 0
    private(set) var diskHits = 0
    private(set) var epoch: UInt64 = 0
    private let policy: ContentCachePolicy
    private let disk: ContentCacheDisk?
    private var memory: [String: MemoryEntry] = [:]
    private var access: UInt64 = 0
    private var cost = 0

    init(directory: URL?, policy: ContentCachePolicy = .init()) {
        self.policy = policy
        disk = directory.map { ContentCacheDisk(directory: $0, policy: policy) }
    }

    static func digest(_ value: Data) -> String {
        SHA256.hash(data: value).map { String(format: "%02x", $0) }.joined()
    }

    func read(key: String) async -> Data? {
        let identifier = Self.digest(Data(key.utf8))
        let ticket = epoch
        access &+= 1
        if var entry = memory[identifier] {
            entry.access = access
            memory[identifier] = entry
            await disk?.touch(identifier)
            if epoch == ticket { memoryHits += 1 }
            return epoch == ticket ? entry.data : nil
        }
        guard let data = await disk?.read(identifier), epoch == ticket else { return nil }
        diskHits += 1
        remember(data, identifier: identifier)
        return data
    }

    @discardableResult
    func write(_ data: Data, key: String, epoch ticket: UInt64) async -> Bool {
        guard ticket == epoch, data.count <= policy.maximumEntryBytes else { return false }
        let identifier = Self.digest(Data(key.utf8))
        let evicted = await disk?.write(data, identifier: identifier, epoch: ticket) ?? []
        guard ticket == epoch else { return false }
        for key in evicted { removeMemory(key) }
        remember(data, identifier: identifier)
        return true
    }

    func remove(key: String) async {
        let identifier = Self.digest(Data(key.utf8))
        removeMemory(identifier)
        await disk?.remove(identifier)
    }

    func clear() async {
        epoch &+= 1
        memory.removeAll()
        cost = 0
        await disk?.clear(epoch: epoch)
    }

    private func remember(_ data: Data, identifier: String) {
        removeMemory(identifier)
        guard data.count <= policy.memoryBytes else { return }
        access &+= 1
        memory[identifier] = MemoryEntry(data: data, access: access)
        cost += data.count
        while memory.count > policy.memoryPages || cost > policy.memoryBytes {
            guard let oldest = memory.min(by: { $0.value.access < $1.value.access })?.key else { break }
            removeMemory(oldest)
        }
    }

    private func removeMemory(_ identifier: String) {
        if let removed = memory.removeValue(forKey: identifier) { cost -= removed.data.count }
    }
}

private actor ContentCacheDisk {
    private struct Entry: Codable {
        let bytes: Int
        var access: Date
    }

    private let directory: URL
    private let policy: ContentCachePolicy
    private var index: [String: Entry] = [:]
    private var prepared = false
    private var epoch: UInt64 = 0

    init(directory: URL, policy: ContentCachePolicy) {
        self.directory = directory
        self.policy = policy
    }

    func read(_ identifier: String) -> Data? {
        prepare()
        guard let metadata = index[identifier], metadata.bytes <= policy.maximumEntryBytes,
              let size = try? file(identifier).resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size == metadata.bytes,
              let data = try? Data(contentsOf: file(identifier)) else {
            remove(identifier)
            return nil
        }
        index[identifier]?.access = Date()
        saveIndex()
        return data
    }

    func write(_ data: Data, identifier: String, epoch ticket: UInt64) -> [String] {
        prepare()
        guard epoch == ticket, data.count <= policy.maximumEntryBytes, data.count <= policy.diskBytes else { return [] }
        do {
            try data.write(to: file(identifier), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            index[identifier] = Entry(bytes: data.count, access: Date())
            let removed = evict()
            saveIndex()
            return removed
        } catch {
            return [] // Cache failure must not fail a successful network read.
        }
    }

    func touch(_ identifier: String) {
        prepare()
        index[identifier]?.access = Date()
        saveIndex()
    }

    func remove(_ identifier: String) {
        prepare()
        index[identifier] = nil
        try? FileManager.default.removeItem(at: file(identifier))
        saveIndex()
    }

    func clear(epoch: UInt64) {
        self.epoch = epoch
        prepare()
        for key in index.keys { try? FileManager.default.removeItem(at: file(key)) }
        index.removeAll()
        saveIndex()
    }

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let indexURL = directory.appendingPathComponent("index.json")
        if let size = try? indexURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 2 * 1_024 * 1_024,
           let data = try? Data(contentsOf: indexURL),
           let saved = try? JSONDecoder().decode([String: Entry].self, from: data) {
            index = saved.filter { $0.key.count == 64 && $0.key.allSatisfy(\.isHexDigit) && $0.value.bytes > 0 }
        }
        // Recover from a crash between the atomic page and index writes without retaining orphan files.
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "cache" && index[url.deletingPathExtension().lastPathComponent] == nil {
            try? FileManager.default.removeItem(at: url)
        }
        _ = evict()
        saveIndex()
    }

    private func evict() -> [String] {
        var total = index.values.reduce(0) { $0 + $1.bytes }
        var removed: [String] = []
        for (key, value) in index.sorted(by: { $0.value.access < $1.value.access }) {
            guard total > policy.diskBytes else { break }
            try? FileManager.default.removeItem(at: file(key))
            total -= value.bytes
            index[key] = nil
            removed.append(key)
        }
        return removed
    }

    private func file(_ identifier: String) -> URL {
        directory.appendingPathComponent(identifier).appendingPathExtension("cache")
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: directory.appendingPathComponent("index.json"), options: .atomic)
    }
}
