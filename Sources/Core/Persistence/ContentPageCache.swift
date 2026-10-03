import CryptoKit
import Foundation

struct ContentCacheIOCounts: Sendable {
    var reads = 0
    var writes = 0
    var indexFlushes = 0
}

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
    private(set) var readRequests = 0
    private let policy: ContentCachePolicy
    private let disk: ContentCacheDisk?
    private var memory: [String: MemoryEntry] = [:]
    private var access: UInt64 = 0
    private var cost = 0
    private var touches: [String: Date] = [:]
    private var maintenanceWake: Task<Void, Never>?
    private var maintenanceWriter: Task<Void, Never>?

    init(directory: URL?, policy: ContentCachePolicy = .init(),
         beforeMaintenanceFlush: (@Sendable () async -> Void)? = nil) {
        self.policy = policy
        disk = directory.map { ContentCacheDisk(directory: $0, policy: policy, beforeMaintenanceFlush: beforeMaintenanceFlush) }
    }

    static func digest(_ value: Data) -> String {
        SHA256.hash(data: value).map { String(format: "%02x", $0) }.joined()
    }

    func read(key: String) async -> Data? {
        readRequests += 1
        let identifier = Self.digest(Data(key.utf8))
        let ticket = epoch
        access &+= 1
        if var entry = memory[identifier] {
            entry.access = access
            memory[identifier] = entry
            touch(identifier)
            memoryHits += 1
            return entry.data
        }
        guard let data = await disk?.read(identifier), epoch == ticket else { return nil }
        diskHits += 1
        remember(data, identifier: identifier)
        touch(identifier)
        return data
    }

    @discardableResult
    func write(_ data: Data, key: String, epoch ticket: UInt64) async -> Bool {
        guard ticket == epoch, data.count <= policy.maximumEntryBytes else { return false }
        let identifier = Self.digest(Data(key.utf8))
        let evicted: [String]
        if let disk {
            let recent = touches
            touches.removeAll(keepingCapacity: true)
            guard let removed = await disk.write(data, identifier: identifier, epoch: ticket, touches: recent) else { return false }
            evicted = removed
        } else { evicted = [] }
        guard ticket == epoch else { return false }
        for key in evicted { removeMemory(key) }
        remember(data, identifier: identifier)
        return true
    }

    func remove(key: String) async {
        let identifier = Self.digest(Data(key.utf8))
        removeMemory(identifier)
        touches[identifier] = nil
        await disk?.remove(identifier)
    }

    func clear() async {
        epoch &+= 1
        memory.removeAll()
        cost = 0
        touches.removeAll()
        maintenanceWake?.cancel()
        maintenanceWake = nil
        await disk?.clear(epoch: epoch)
    }

    func ioCounts() async -> ContentCacheIOCounts { await disk?.counts ?? .init() }

    /// Metadata only: checking page references must not read/touch every old body.
    func contains(keys: [String], epoch ticket: UInt64) async -> Bool {
        guard epoch == ticket else { return false }
        let ids = keys.map { Self.digest(Data($0.utf8)) }
        let present: Bool
        if let disk { present = await disk.contains(ids) } else { present = ids.allSatisfy { memory[$0] != nil } }
        return epoch == ticket && present
    }

    /// An explicit barrier, also used by tests instead of waiting for the maintenance timer.
    func flushMaintenance() async {
        maintenanceWake?.cancel()
        maintenanceWake = nil
        if maintenanceWriter == nil, !touches.isEmpty {
            maintenanceWriter = Task { await self.drainTouches() }
        }
        await maintenanceWriter?.value
    }

    private func touch(_ identifier: String) {
        guard disk != nil else { return }
        // Only recency is approximate; a burst cannot accumulate an unbounded key queue.
        if touches.count < 256 || touches[identifier] != nil { touches[identifier] = Date() }
        guard maintenanceWake == nil, maintenanceWriter == nil else { return }
        maintenanceWake = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            await self?.maintenanceDue()
        }
    }

    private func maintenanceDue() async {
        guard !Task.isCancelled else { return }
        maintenanceWake = nil
        await flushMaintenance()
    }

    private func drainTouches() async {
        while !touches.isEmpty {
            let batch = touches
            touches.removeAll(keepingCapacity: true)
            await disk?.touch(batch, epoch: epoch)
        }
        maintenanceWriter = nil
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
    private(set) var counts = ContentCacheIOCounts()
    private struct Entry: Codable {
        let bytes: Int
        var access: Date
    }

    private let directory: URL
    private let policy: ContentCachePolicy
    private var index: [String: Entry] = [:]
    private var prepared = false
    private var epoch: UInt64 = 0
    private let beforeMaintenanceFlush: (@Sendable () async -> Void)?

    init(directory: URL, policy: ContentCachePolicy, beforeMaintenanceFlush: (@Sendable () async -> Void)?) {
        self.directory = directory
        self.policy = policy
        self.beforeMaintenanceFlush = beforeMaintenanceFlush
    }

    func read(_ identifier: String) -> Data? {
        prepare()
        guard let metadata = index[identifier] else { return nil }
        guard metadata.bytes <= policy.maximumEntryBytes,
              let size = try? file(identifier).resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size == metadata.bytes,
              let data = try? Data(contentsOf: file(identifier)) else {
            remove(identifier)
            return nil
        }
        counts.reads += 1
        return data
    }

    func write(_ data: Data, identifier: String, epoch ticket: UInt64, touches: [String: Date]) -> [String]? {
        prepare()
        guard epoch == ticket, data.count <= policy.maximumEntryBytes, data.count <= policy.diskBytes else { return nil }
        for (key, date) in touches where index[key] != nil { index[key]?.access = date }
        do {
            try data.write(to: file(identifier), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            counts.writes += 1
            index[identifier] = Entry(bytes: data.count, access: Date())
            let removed = evict()
            try saveIndex()
            guard index[identifier] != nil else { return nil }
            return removed
        } catch {
            index[identifier] = nil
            try? FileManager.default.removeItem(at: file(identifier))
            return nil // Never claim the page is persisted when the index/file write failed.
        }
    }

    func touch(_ batch: [String: Date], epoch ticket: UInt64) async {
        await beforeMaintenanceFlush?()
        prepare()
        guard epoch == ticket else { return }
        var changed = false
        for (key, date) in batch where index[key] != nil {
            index[key]?.access = date
            changed = true
        }
        if changed { try? saveIndex() }
    }

    func contains(_ identifiers: [String]) -> Bool {
        prepare()
        return identifiers.allSatisfy { index[$0] != nil }
    }

    func remove(_ identifier: String) {
        prepare()
        guard index[identifier] != nil else { return }
        index[identifier] = nil
        try? FileManager.default.removeItem(at: file(identifier))
        try? saveIndex()
    }

    func clear(epoch: UInt64) {
        guard epoch >= self.epoch else { return }
        self.epoch = epoch
        prepare()
        for key in index.keys { try? FileManager.default.removeItem(at: file(key)) }
        index.removeAll()
        try? saveIndex()
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
        if !evict().isEmpty { try? saveIndex() }
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

    private func saveIndex() throws {
        let data = try JSONEncoder().encode(index)
        try data.write(to: directory.appendingPathComponent("index.json"), options: .atomic)
        counts.indexFlushes += 1
    }
}
