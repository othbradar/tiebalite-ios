import Foundation

protocol BrowsingHistoryRepository: Sendable {
    func load() async throws -> [BrowsingHistoryEntry]
    func record(_ entry: BrowsingHistoryEntry) async throws
    func delete(_ identity: BrowsingHistoryIdentity) async throws
    func clear() async throws
}

actor InMemoryBrowsingHistoryRepository: BrowsingHistoryRepository {
    private var entries: [BrowsingHistoryEntry]
    private let maximumCount: Int

    init(
        entries: [BrowsingHistoryEntry] = [],
        maximumCount: Int = 500
    ) {
        self.maximumCount = max(1, maximumCount)
        self.entries = Array(entries.prefix(max(1, maximumCount)))
    }

    func load() -> [BrowsingHistoryEntry] {
        entries
    }

    func record(_ entry: BrowsingHistoryEntry) {
        Self.upsert(entry, in: &entries, maximumCount: maximumCount)
    }

    func delete(_ identity: BrowsingHistoryIdentity) {
        entries.removeAll { $0.identity == identity }
    }

    func clear() {
        entries.removeAll(keepingCapacity: false)
    }

    fileprivate static func upsert(
        _ entry: BrowsingHistoryEntry,
        in entries: inout [BrowsingHistoryEntry],
        maximumCount: Int
    ) {
        let previous = entries.first { $0.identity == entry.identity }
        entries.removeAll { $0.identity == entry.identity }
        entries.insert(previous?.revisited(with: entry) ?? entry, at: 0)
        if entries.count > maximumCount {
            entries.removeLast(entries.count - maximumCount)
        }
    }
}

actor JSONBrowsingHistoryRepository: BrowsingHistoryRepository {
    static let defaultMaximumCount = 500

    private struct Envelope: Codable, Sendable {
        let schemaVersion: Int
        let entries: [BrowsingHistoryEntry]
    }

    private let fileURL: URL
    private let maximumCount: Int
    private var cachedEntries: [BrowsingHistoryEntry]?

    init(
        fileURL: URL,
        maximumCount: Int = defaultMaximumCount
    ) {
        self.fileURL = fileURL
        self.maximumCount = max(1, maximumCount)
    }

    static func production(
        fileManager: FileManager = .default
    ) -> JSONBrowsingHistoryRepository {
        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL.applicationSupportDirectory
        return JSONBrowsingHistoryRepository(
            fileURL: baseURL
                .appendingPathComponent("TiebaLite", isDirectory: true)
                .appendingPathComponent("browsing-history.json")
        )
    }

    func load() throws -> [BrowsingHistoryEntry] {
        try loadEntries()
    }

    func record(_ entry: BrowsingHistoryEntry) throws {
        var entries = try loadEntries()
        InMemoryBrowsingHistoryRepository.upsert(
            entry,
            in: &entries,
            maximumCount: maximumCount
        )
        try persist(entries)
    }

    func delete(_ identity: BrowsingHistoryIdentity) throws {
        var entries = try loadEntries()
        entries.removeAll { $0.identity == identity }
        try persist(entries)
    }

    func clear() throws {
        try persist([])
    }

    private func loadEntries() throws -> [BrowsingHistoryEntry] {
        if let cachedEntries {
            return cachedEntries
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedEntries = []
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.schemaVersion == 1 else {
            throw BrowsingHistoryError.invalidSchema
        }
        let entries = Array(envelope.entries.prefix(maximumCount))
        cachedEntries = entries
        return entries
    }

    private func persist(_ entries: [BrowsingHistoryEntry]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(Envelope(
            schemaVersion: 1,
            entries: entries
        ))
        try data.write(to: fileURL, options: .atomic)
        cachedEntries = entries
    }
}
