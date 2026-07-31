#if DEBUG
enum MediaHorizontalBoundary: Equatable, Sendable {
    case both
    case interior
    case leading
    case trailing
}

enum MediaHorizontalIntent: Equatable, Sendable {
    case towardNext
    case towardPrevious
    case verticalOrAmbiguous
}

enum MediaGestureOwner: Equatable, Sendable {
    case pager
    case zoomPage
}

struct MediaPageCapability: Equatable, Sendable {
    static let minimumZoom = MediaPageCapability(
        atMinimumZoom: true,
        horizontalBoundary: .both
    )

    let atMinimumZoom: Bool
    let horizontalBoundary: MediaHorizontalBoundary
}

struct MediaGestureSession<MediaID>: Equatable, Sendable
where MediaID: Hashable & Sendable {
    let mediaID: MediaID
    let owner: MediaGestureOwner
    private(set) var latestCapability: MediaPageCapability

    static func begin(
        mediaID: MediaID,
        capability: MediaPageCapability,
        intent: MediaHorizontalIntent
    ) -> Self {
        Self(
            mediaID: mediaID,
            owner: owner(capability: capability, intent: intent),
            latestCapability: capability
        )
    }

    func updatingCapability(
        _ capability: MediaPageCapability
    ) -> Self {
        Self(
            mediaID: mediaID,
            owner: owner,
            latestCapability: capability
        )
    }

    private static func owner(
        capability: MediaPageCapability,
        intent: MediaHorizontalIntent
    ) -> MediaGestureOwner {
        guard intent != .verticalOrAmbiguous else {
            return .zoomPage
        }
        if capability.atMinimumZoom {
            return .pager
        }

        switch (capability.horizontalBoundary, intent) {
        case (.both, _),
             (.leading, .towardPrevious),
             (.trailing, .towardNext):
            return .pager
        case (.interior, _),
             (.leading, .towardNext),
             (.trailing, .towardPrevious),
             (_, .verticalOrAmbiguous):
            return .zoomPage
        }
    }
}

struct MediaZoomStateRegistry<MediaID>: Equatable, Sendable
where MediaID: Hashable & Sendable {
    private var capabilities: [MediaID: MediaPageCapability] = [:]

    var trackedIDs: Set<MediaID> {
        Set(capabilities.keys)
    }

    mutating func update(
        _ capability: MediaPageCapability,
        for mediaID: MediaID
    ) {
        capabilities[mediaID] = capability
    }

    func capability(for mediaID: MediaID) -> MediaPageCapability {
        capabilities[mediaID] ?? .minimumZoom
    }

    mutating func resolveDeparture(
        sourceID: MediaID,
        targetID: MediaID,
        completed: Bool
    ) {
        guard completed else {
            return
        }
        capabilities[sourceID] = .minimumZoom
        if capabilities[targetID] == nil {
            capabilities[targetID] = .minimumZoom
        }
    }

    mutating func close() {
        capabilities.removeAll(keepingCapacity: false)
    }
}
#endif
