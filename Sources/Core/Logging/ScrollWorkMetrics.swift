#if UITESTING
import Synchronization

/// Test-window counters only. No content, identifiers or timing I/O in a rendered frame.
enum ScrollWorkMetrics {
    private static let storage = Mutex<[String: Int]?>(nil)
    static func start() { storage.withLock { $0 = [:] } }
    static func stop() -> [String: Int] { storage.withLock { let result = $0 ?? [:]; $0 = nil; return result } }
    static func value(_ name: String) -> Int { storage.withLock { $0?[name, default: 0] ?? 0 } }
    static func count(_ name: String) { storage.withLock { if $0 != nil { $0?[name, default: 0] += 1 } } }
}
#endif
