import Foundation

/// Only confirmed, globally removed public IDs. Independent of the evictable
/// reading cache, so an old page or account switch cannot resurrect a deletion.
actor ContentRemovalRepository {
    private let file: URL?
    private var entries: [ConfirmedContentRemoval]?
    init(file: URL?) { self.file = file }
    static func production() -> ContentRemovalRepository {
        .init(file: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ConfirmedRemovals-v1.json"))
    }
    func load() throws -> [ConfirmedContentRemoval] {
        if let entries { return entries }
        let values: [ConfirmedContentRemoval]
        if let file, FileManager.default.fileExists(atPath: file.path) {
            values = try JSONDecoder().decode([ConfirmedContentRemoval].self, from: Data(contentsOf: file))
        } else { values = [] }
        guard values.count <= 4_096, values.allSatisfy({ $0.target.isValid }) else { throw ContentActionFailure.storageUnavailable }
        entries = values
        return values
    }
    /// Fail before the remote mutation if the local ledger is full or unwritable.
    func prepare() throws {
        let values = try load()
        guard values.count < 4_096 else { throw ContentActionFailure.storageUnavailable }
        try persist(values)
    }
    func record(_ target: ContentActionTarget) throws -> [ConfirmedContentRemoval] {
        guard target.isValid else { throw ContentActionFailure.unavailable }
        var values = try load().filter { $0.target != target }
        values.append(.init(target: target, date: .now))
        try persist(values)
        entries = values
        return values
    }
    private func persist(_ values: [ConfirmedContentRemoval]) throws {
        guard let file else { return }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: file, options: .atomic)
    }
}
