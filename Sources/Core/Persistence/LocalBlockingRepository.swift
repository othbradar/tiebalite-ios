import Foundation

/// Separate application-support file per local account namespace. Clearing
/// content/image caches cannot delete this user choice or another account's list.
actor LocalBlockingRepository {
    private let directory: URL?
    private var values: [String: [BlockedProfile]] = [:]
    init(directory: URL?) { self.directory = directory }
    static func production() -> LocalBlockingRepository {
        .init(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("LocalBlockedUsers-v1", isDirectory: true))
    }
    func load(namespace: String) throws -> [BlockedProfile] {
        if let entries = values[namespace] { return entries }
        guard let file = file(namespace), FileManager.default.fileExists(atPath: file.path) else { return [] }
        let entries = try JSONDecoder().decode([BlockedProfile].self, from: Data(contentsOf: file)).filter { $0.id > 0 }
        values[namespace] = entries
        return entries
    }
    func set(_ entry: BlockedProfile, blocked: Bool, namespace: String) throws -> [BlockedProfile] {
        guard entry.id > 0 else { throw ProfileContentFailure.invalidData }
        var entries = try load(namespace: namespace).filter { $0.id != entry.id }
        if blocked { entries.append(entry) }
        if let directory, let file = file(namespace) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: file, options: .atomic)
        }
        values[namespace] = entries
        return entries
    }
    private func file(_ namespace: String) -> URL? {
        directory?.appendingPathComponent(ContentPageCache.digest(Data(namespace.utf8))).appendingPathExtension("json")
    }
}
