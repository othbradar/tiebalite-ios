import Foundation
import Observation

@MainActor @Observable
final class ContentRemovalVisibility {
    static let shared = ContentRemovalVisibility()
    private(set) var targets = Set<ContentActionTarget>()
    private(set) var dates: [ContentActionTarget: Date] = [:]
    private(set) var revision: UInt64 = 0
    @ObservationIgnored private let readers = NSMapTable<AnyObject, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    func readerChanged(_ reader: AnyObject) -> Bool {
        let changed = readers.object(forKey: reader)?.uint64Value != revision
        readers.setObject(NSNumber(value: revision), forKey: reader)
        return changed
    }
    var threadIDs: Set<Int64> { Set(targets.filter { $0.kind == .thread }.map(\.threadID)) }
    func update(_ entries: [ConfirmedContentRemoval]) {
        targets = Set(entries.map(\.target))
        dates = Dictionary(entries.map { ($0.target, $0.date) }, uniquingKeysWith: max)
        revision &+= 1
    }
    func removedSubposts(thread: Int64, parent: Int64, after date: Date) -> Set<Int64> {
        Set(dates.compactMap { target, removedAt in
            target.kind == .subpost && target.threadID == thread && target.parentPostID == parent && removedAt > date ? target.postID : nil
        })
    }
    func contains(_ source: ThreadContentSource) -> Bool {
        targets.contains { $0.threadID == source.threadID && ($0.kind == .thread || $0.postID == source.postID) }
    }
    func contains(thread: Int64, parent: Int64 = 0) -> Bool {
        targets.contains { $0.threadID == thread && ($0.kind == .thread || ($0.kind == .post && $0.postID == parent)) }
    }
}
