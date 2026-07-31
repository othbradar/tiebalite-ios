#if DEBUG
struct PagerTransitionToken: Equatable, Hashable, Sendable {
    fileprivate let sequence: UInt64
}

struct PagerTransition<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let token: PagerTransitionToken
    let sourceID: PageID
    let targetID: PageID
    let frozenOrder: [PageID]
    let participantIDs: [PageID]
}

struct PagerStateMachine<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    private(set) var displayedOrder: [PageID]
    private(set) var committedID: PageID?
    private(set) var transition: PagerTransition<PageID>?
    private(set) var pendingOrder: [PageID]?
    private(set) var resolvedTransitionCount = 0

    private var nextTransitionSequence: UInt64 = 1

    init(pageIDs: [PageID], committedID: PageID?) {
        displayedOrder = Self.hasUniqueIDs(pageIDs) ? pageIDs : []
        if let committedID, displayedOrder.contains(committedID) {
            self.committedID = committedID
        } else {
            self.committedID = nil
        }
    }

    mutating func beginTransition(
        to targetID: PageID
    ) -> PagerTransitionToken? {
        guard transition == nil,
              let sourceID = committedID,
              sourceID != targetID,
              let sourceIndex = displayedOrder.firstIndex(of: sourceID),
              let targetIndex = displayedOrder.firstIndex(of: targetID),
              abs(sourceIndex - targetIndex) == 1 else {
            return nil
        }

        let token = PagerTransitionToken(
            sequence: nextTransitionSequence
        )
        nextTransitionSequence &+= 1
        transition = PagerTransition(
            token: token,
            sourceID: sourceID,
            targetID: targetID,
            frozenOrder: displayedOrder,
            participantIDs: PagerCachePolicy.participantIDs(
                pageIDs: displayedOrder,
                sourceID: sourceID,
                targetID: targetID
            )
        )
        return token
    }

    @discardableResult
    mutating func updatePages(_ pageIDs: [PageID]) -> Bool {
        guard Self.hasUniqueIDs(pageIDs) else {
            return false
        }

        if transition != nil {
            pendingOrder = pageIDs
            return true
        }

        let previousOrder = displayedOrder
        displayedOrder = pageIDs
        committedID = Self.reconciledSelection(
            committedID,
            previousOrder: previousOrder,
            nextOrder: pageIDs
        )
        return true
    }

    @discardableResult
    mutating func selectImmediately(_ pageID: PageID?) -> Bool {
        guard transition == nil else {
            return false
        }
        guard let pageID else {
            committedID = nil
            return true
        }
        guard displayedOrder.contains(pageID) else {
            return false
        }
        committedID = pageID
        return true
    }

    @discardableResult
    mutating func resolveTransition(
        token: PagerTransitionToken,
        completed: Bool
    ) -> Bool {
        guard let activeTransition = transition,
              activeTransition.token == token else {
            return false
        }

        let resolvedID = completed
            ? activeTransition.targetID
            : activeTransition.sourceID
        transition = nil
        resolvedTransitionCount += 1

        if let pendingOrder {
            displayedOrder = pendingOrder
            committedID = Self.reconciledSelection(
                resolvedID,
                previousOrder: activeTransition.frozenOrder,
                nextOrder: pendingOrder
            )
            self.pendingOrder = nil
        } else {
            committedID = resolvedID
        }
        return true
    }

    private static func hasUniqueIDs(_ pageIDs: [PageID]) -> Bool {
        Set(pageIDs).count == pageIDs.count
    }

    private static func reconciledSelection(
        _ selection: PageID?,
        previousOrder: [PageID],
        nextOrder: [PageID]
    ) -> PageID? {
        guard let selection else {
            return nil
        }
        if nextOrder.contains(selection) {
            return selection
        }
        guard let removedIndex = previousOrder.firstIndex(of: selection) else {
            return nil
        }

        let nextIDs = previousOrder.dropFirst(removedIndex + 1)
        if let nextSurvivor = nextIDs.first(where: nextOrder.contains) {
            return nextSurvivor
        }

        let previousIDs = previousOrder.prefix(upTo: removedIndex).reversed()
        return previousIDs.first(where: nextOrder.contains)
    }
}

enum PagerCachePolicy {
    static func liveIDs<PageID>(
        pageIDs: [PageID],
        committedID: PageID?,
        transition: PagerTransition<PageID>?
    ) -> [PageID] where PageID: Hashable & Sendable {
        if let transition {
            return transition.participantIDs
        }
        guard let committedID,
              let index = pageIDs.firstIndex(of: committedID) else {
            return []
        }
        let lowerBound = max(pageIDs.startIndex, index - 1)
        let upperBound = min(pageIDs.endIndex, index + 2)
        return Array(pageIDs[lowerBound..<upperBound])
    }

    static func participantIDs<PageID>(
        pageIDs: [PageID],
        sourceID: PageID,
        targetID: PageID
    ) -> [PageID] where PageID: Hashable & Sendable {
        guard let sourceIndex = pageIDs.firstIndex(of: sourceID),
              let targetIndex = pageIDs.firstIndex(of: targetID) else {
            return []
        }

        let lowerBound = max(
            pageIDs.startIndex,
            min(sourceIndex, targetIndex) - 1
        )
        let upperBound = min(
            pageIDs.endIndex,
            max(sourceIndex, targetIndex) + 2
        )
        return Array(pageIDs[lowerBound..<upperBound])
    }
}
#endif
