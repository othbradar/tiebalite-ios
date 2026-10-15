enum VideoPlaybackMode: String, Codable, CaseIterable, Sendable {
    case manual
    case automatic
}

/// Visible candidates only. A paused/ended/failed owner retains its turn until it leaves.
struct VideoAutoplayState {
    var mode = VideoPlaybackMode.manual
    private var candidates: [String: MediaPlaybackSource] = [:]
    private var order: [String] = []
    private var suspended: Set<String> = []

    mutating func update(owner: String, source: MediaPlaybackSource?, visible: Bool) {
        guard visible, let source else {
            candidates[owner] = nil
            order.removeAll { $0 == owner }
            suspended.remove(owner)
            return
        }
        if candidates[owner] == nil { order.append(owner) }
        candidates[owner] = source
    }

    mutating func suspendVisible() { suspended.formUnion(order) }

    func next(currentOwner: String?) -> (owner: String, source: MediaPlaybackSource)? {
        guard mode == .automatic, currentOwner == nil,
              let owner = order.first(where: { !suspended.contains($0) }), let source = candidates[owner] else { return nil }
        return (owner, source)
    }
}
