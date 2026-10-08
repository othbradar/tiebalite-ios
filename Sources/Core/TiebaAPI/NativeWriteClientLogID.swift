import Foundation

/// IDPClientLogIDProduter: truncate the first timestamp to seconds, multiply
/// by 1000, then increment for each load. This is this process's own sequence.
struct NativeWriteClientLogID {
    private var current: Int64?

    mutating func next(timestamp: TimeInterval) -> Int64 {
        let value = (current ?? Int64(timestamp) * 1_000) + 1
        current = value
        return value
    }
}
