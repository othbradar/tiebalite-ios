import Foundation
import Observation

/// Main-actor projection of the active account's persisted local choices.
/// It contains only public UIDs; it does not mutate raw server pages or cursors.
@MainActor @Observable
final class LocalUserVisibility {
    static let shared = LocalUserVisibility()
    private(set) var ids = Set<Int64>()
    private(set) var revision: UInt64 = 0
    @ObservationIgnored private let readerVersions = NSMapTable<AnyObject, NSNumber>(keyOptions: .weakMemory,
                                                                                     valueOptions: .strongMemory)
    func update(_ ids: Set<Int64>) { self.ids = ids; revision &+= 1 }
    func readerChanged(_ reader: AnyObject) -> Bool {
        let changed = readerVersions.object(forKey: reader)?.uint64Value != revision
        readerVersions.setObject(NSNumber(value: revision), forKey: reader)
        return changed
    }
}
