import Foundation

struct MediaPlaybackSource: Equatable, Sendable {
    let url: URL

    static func video(_ value: String) -> Self? {
        guard value.utf8.count <= 2_048, var parts = URLComponents(string: value) else { return nil }
        // Verified against a real PbContent link: identical path/query over TLS returns 206 video/mp4.
        if parts.scheme?.lowercased() == "http", parts.host?.lowercased() == "tb-video.bdstatic.com", parts.port == nil {
            parts.scheme = "https"
        }
        guard parts.scheme?.lowercased() == "https",
              parts.host?.isEmpty == false, parts.user == nil, parts.password == nil,
              parts.fragment == nil, let url = parts.url else { return nil }
        return Self(url: url)
    }

    static func voice(resourceID: String?) -> Self? {
        guard let resourceID, !resourceID.isEmpty, resourceID.utf8.count <= 256 else { return nil }
        var parts = URLComponents()
        parts.scheme = "https"
        parts.host = "tiebac.baidu.com"
        parts.path = "/c/p/voice"
        parts.queryItems = [.init(name: "voice_md5", value: resourceID)]
        return parts.url.map { Self(url: $0) }
    }
}

struct MediaPlaybackState: Equatable, Sendable {
    enum Phase: Equatable, Sendable { case idle, loading, playing, paused, ended, failed }
    private(set) var owner: String?
    private(set) var generation: UInt64 = 0
    private(set) var phase = Phase.idle
    private(set) var elapsed = 0.0
    private(set) var duration = 0.0
    var fraction: Double { duration > 0 ? min(1, max(0, elapsed / duration)) : 0 }

    @discardableResult
    mutating func begin(owner: String) -> UInt64 {
        generation &+= 1
        self.owner = owner
        phase = .loading
        elapsed = 0
        duration = 0
        return generation
    }

    mutating func update(ticket: UInt64, phase: Phase, elapsed: Double, duration: Double) {
        guard ticket == generation, owner != nil else { return }
        self.phase = phase
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.elapsed = elapsed.isFinite ? max(0, elapsed) : 0
    }

    mutating func stop(owner: String) {
        guard self.owner == owner else { return }
        generation &+= 1
        self.owner = nil
        phase = .idle
        elapsed = 0
        duration = 0
    }
}
