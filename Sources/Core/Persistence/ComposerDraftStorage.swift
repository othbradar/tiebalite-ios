import CryptoKit
import Foundation

/// User-authored data lives outside both disposable caches. No credentials or upload receipts are encoded.
actor ComposerDraftStorage {
    struct Key: Hashable, Sendable {
        let namespace: String
        let target: String
    }

    enum Failure: Error { case capacity, attachmentUnavailable }

    private struct Photo: Codable {
        let id: String
        let name: String
        let width: Int
        let height: Int
        let byteCount: Int
    }
    private struct Record: Codable {
        let title: String
        let content: String
        let photos: [Photo]
    }

    private let directory: URL
    private let maximumBytes: Int
    private let maximumDrafts = 64
    private let files = FileManager.default

    init(directory: URL, maximumBytes: Int = 256 * 1_024 * 1_024) {
        self.directory = directory
        self.maximumBytes = maximumBytes
    }

    static func production() -> ComposerDraftStorage? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first.map {
            ComposerDraftStorage(directory: $0.appendingPathComponent("ComposerDrafts-v1", isDirectory: true))
        }
    }

    func load(_ key: Key) throws -> TextDraft {
        let folder = folder(key)
        let recordURL = folder.appendingPathComponent("draft.json")
        guard files.fileExists(atPath: recordURL.path) else { return TextDraft() }
        let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: recordURL))
        var draft = TextDraft(title: record.title, content: record.content)
        for photo in record.photos {
            guard photo.name == Self.digest(photo.id) + ".photo" else { throw Failure.attachmentUnavailable }
            let url = folder.appendingPathComponent(photo.name)
            guard files.fileExists(atPath: url.path), try size(url) == photo.byteCount else { throw Failure.attachmentUnavailable }
            draft.photos.append(.init(id: photo.id, file: .init(url: url, removesOnRelease: false),
                                      width: photo.width, height: photo.height, byteCount: photo.byteCount))
        }
        try removeOrphans(in: folder, keeping: Set(record.photos.map(\.name)))
        return draft
    }

    func save(_ draft: TextDraft, key: Key) throws {
        let folder = folder(key)
        if draft.title.isEmpty, draft.content.isEmpty, draft.photos.isEmpty,
           !files.fileExists(atPath: folder.appendingPathComponent("draft.json").path) { return }
        let photos = draft.photos.map {
            Photo(id: $0.id, name: Self.digest($0.id) + ".photo", width: $0.width, height: $0.height, byteCount: $0.byteCount)
        }
        let data = try JSONEncoder().encode(Record(title: draft.title, content: draft.content, photos: photos))
        guard data.count <= 1_024 * 1_024, photos.count <= ComposerPhoto.limit else { throw Failure.capacity }
        let used = try usage(excluding: folder)
        let proposed = photos.reduce(data.count) { $0 + $1.byteCount }
        guard used.count < maximumDrafts, used.bytes + proposed <= maximumBytes else { throw Failure.capacity }
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifest = folder.appendingPathComponent("draft.json")
        let oldPhotos: Set<String>
        if files.fileExists(atPath: manifest.path) {
            oldPhotos = Set(try JSONDecoder().decode(Record.self, from: Data(contentsOf: manifest)).photos.map(\.name))
        } else { oldPhotos = [] }
        do {
            try copyPhotos(draft.photos, records: photos, into: folder)
            // Attachments are durable before publishing their manifest; any earlier failure preserves the old draft.
            try data.write(to: manifest, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            try removeOrphans(in: folder, keeping: oldPhotos)
            throw error
        }
        try removeOrphans(in: folder, keeping: Set(photos.map(\.name)))
    }

    private func copyPhotos(_ photos: [ComposerPhoto], records: [Photo], into folder: URL) throws {
        for (photo, stored) in zip(photos, records) {
            let destination = folder.appendingPathComponent(stored.name)
            if !files.fileExists(atPath: destination.path) {
                guard try size(photo.file.url) == photo.byteCount else { throw Failure.attachmentUnavailable }
                try files.copyItem(at: photo.file.url, to: destination)
            }
            guard try size(destination) == photo.byteCount else { throw Failure.attachmentUnavailable }
        }
    }

    func clear(_ key: Key) throws { try removeIfPresent(folder(key)) }
    func revoke(_ namespace: String) throws { try removeIfPresent(directory.appendingPathComponent(Self.digest(namespace))) }

    private func folder(_ key: Key) -> URL {
        directory.appendingPathComponent(Self.digest(key.namespace), isDirectory: true)
            .appendingPathComponent(Self.digest(key.target), isDirectory: true)
    }

    private func usage(excluding excluded: URL) throws -> (bytes: Int, count: Int) {
        guard files.fileExists(atPath: directory.path) else { return (0, 0) }
        var bytes = 0
        var count = 0
        for account in try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for target in try files.contentsOfDirectory(at: account, includingPropertiesForKeys: nil) where target != excluded {
                let manifest = target.appendingPathComponent("draft.json")
                // An interrupted first save has no user-authored manifest; only its orphan attachments can be removed.
                guard files.fileExists(atPath: manifest.path) else { try files.removeItem(at: target); continue }
                let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: manifest))
                try removeOrphans(in: target, keeping: Set(record.photos.map(\.name)))
                count += 1
                for file in try files.contentsOfDirectory(at: target, includingPropertiesForKeys: nil) { bytes += try size(file) }
            }
        }
        return (bytes, count)
    }

    private func removeOrphans(in folder: URL, keeping names: Set<String>) throws {
        for url in try files.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        where url.pathExtension == "photo" && !names.contains(url.lastPathComponent) {
            try files.removeItem(at: url)
        }
    }

    private func removeIfPresent(_ url: URL) throws {
        if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
    }

    private func size(_ url: URL) throws -> Int {
        try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
