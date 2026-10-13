import CryptoKit
import Foundation

/// Durable user bookmarks are deliberately outside every cache directory and eviction path.
actor BookmarkRepository: BookmarkRepositoryProtocol {
    private struct Envelope: Codable { let version: Int; let entries: [ThreadBookmark] }
    private let directory: URL?
    private var memory: [String: [ThreadBookmark]] = [:]

    init(directory: URL?) { self.directory = directory }

    static func production() -> BookmarkRepository {
        .init(directory: URL.applicationSupportDirectory.appendingPathComponent("TiebaLite/Bookmarks-v1", isDirectory: true))
    }

    func entries(account: String) throws -> [ThreadBookmark] {
        guard !account.isEmpty else { throw BookmarkFailure.accountUnavailable }
        if let cached = memory[account] { return cached }
        guard let file = file(account), FileManager.default.fileExists(atPath: file.path) else { return [] }
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: file))
        guard envelope.version == 1, envelope.entries.allSatisfy(\.isValid),
              Set(envelope.entries.map(\.id)).count == envelope.entries.count else { throw BookmarkFailure.invalidData }
        memory[account] = envelope.entries
        return envelope.entries
    }

    func save(_ entry: ThreadBookmark, account: String) throws {
        guard entry.isValid else { throw BookmarkFailure.invalidData }
        var values = try entries(account: account)
        values.removeAll { $0.id == entry.id }
        values.insert(entry, at: 0)
        try persist(values, account: account)
    }

    func remove(threadID: Int64, account: String) throws {
        var values = try entries(account: account)
        values.removeAll { $0.id == threadID }
        try persist(values, account: account)
    }

    private func persist(_ entries: [ThreadBookmark], account: String) throws {
        try Task.checkCancellation()
        if let directory, let file = file(account) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let bytes = try JSONEncoder().encode(Envelope(version: 1, entries: entries))
            try Task.checkCancellation()
            try bytes.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        memory[account] = entries
    }

    private func file(_ account: String) -> URL? {
        let name = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory?.appendingPathComponent(name + ".json")
    }
}
