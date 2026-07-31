import Testing
@testable import TiebaLite

struct PagerStateMachineTests {
    @Test
    func transitionFreezesParticipantsAndDefersPageUpdatesUntilResolution() throws {
        var state = PagerStateMachine(
            pageIDs: ["p0", "p1", "p2", "p3"],
            committedID: "p1"
        )

        let tokenCandidate = state.beginTransition(to: "p2")
        let token = try #require(tokenCandidate)
        let transition = try #require(state.transition)

        #expect(transition.token == token)
        #expect(transition.sourceID == "p1")
        #expect(transition.targetID == "p2")
        #expect(transition.frozenOrder == ["p0", "p1", "p2", "p3"])
        #expect(transition.participantIDs == ["p0", "p1", "p2", "p3"])

        let updateAccepted = state.updatePages(
            ["inserted", "p0", "p1", "p2", "p3"]
        )
        #expect(updateAccepted)
        #expect(state.displayedOrder == ["p0", "p1", "p2", "p3"])
        #expect(
            state.pendingOrder == ["inserted", "p0", "p1", "p2", "p3"]
        )

        let resolved = state.resolveTransition(
            token: token,
            completed: true
        )
        #expect(resolved)
        #expect(state.committedID == "p2")
        #expect(
            state.displayedOrder == ["inserted", "p0", "p1", "p2", "p3"]
        )
        #expect(state.pendingOrder == nil)
    }

    @Test
    func cancelledAndDuplicateCompletionsNeverCommitTheTarget() throws {
        var state = PagerStateMachine(
            pageIDs: ["p0", "p1", "p2"],
            committedID: "p1"
        )
        let tokenCandidate = state.beginTransition(to: "p2")
        let token = try #require(tokenCandidate)

        let cancelled = state.resolveTransition(
            token: token,
            completed: false
        )
        #expect(cancelled)
        #expect(state.committedID == "p1")
        #expect(state.resolvedTransitionCount == 1)
        let duplicate = state.resolveTransition(
            token: token,
            completed: true
        )
        #expect(!duplicate)
        #expect(state.committedID == "p1")
        #expect(state.resolvedTransitionCount == 1)
    }

    @Test
    func staleCompletionCannotOverwriteANewerReverseTransition() throws {
        var state = PagerStateMachine(
            pageIDs: ["p0", "p1", "p2"],
            committedID: "p1"
        )
        let staleTokenCandidate = state.beginTransition(to: "p2")
        let staleToken = try #require(staleTokenCandidate)
        let cancelled = state.resolveTransition(
            token: staleToken,
            completed: false
        )
        #expect(cancelled)

        let currentTokenCandidate = state.beginTransition(to: "p0")
        let currentToken = try #require(currentTokenCandidate)
        let staleResolution = state.resolveTransition(
            token: staleToken,
            completed: true
        )
        #expect(!staleResolution)
        let currentResolution = state.resolveTransition(
            token: currentToken,
            completed: true
        )
        #expect(currentResolution)
        #expect(state.committedID == "p0")
        #expect(state.resolvedTransitionCount == 2)
    }

    @Test
    func deletionFallsForwardThenBackwardWithoutIndexIdentityTheft() {
        var state = PagerStateMachine(
            pageIDs: ["p0", "p1", "p2", "p3"],
            committedID: "p1"
        )

        let forwardUpdate = state.updatePages(["p0", "p2", "p3"])
        #expect(forwardUpdate)
        #expect(state.committedID == "p2")

        let backwardUpdate = state.updatePages(["p0"])
        #expect(backwardUpdate)
        #expect(state.committedID == "p0")

        let replacementUpdate = state.updatePages(["new"])
        #expect(replacementUpdate)
        #expect(state.committedID == nil)
        #expect(state.displayedOrder == ["new"])
    }

    @Test
    func insertionAndReorderingPreserveTheCommittedBusinessID() {
        var state = PagerStateMachine(
            pageIDs: ["p0", "p1", "p2"],
            committedID: "p1"
        )

        let updateAccepted = state.updatePages(
            ["p2", "inserted", "p1", "p0"]
        )
        #expect(updateAccepted)
        #expect(state.committedID == "p1")
        #expect(state.displayedOrder == ["p2", "inserted", "p1", "p0"])
    }

    @Test
    func duplicateIDsAndNonAdjacentTargetsAreRejectedWithoutMutation() {
        var state = PagerStateMachine(
            pageIDs: ["p0", "p1", "p2"],
            committedID: "p0"
        )
        let before = state

        let duplicateUpdate = state.updatePages(["p0", "p0", "p1"])
        #expect(!duplicateUpdate)
        #expect(state == before)
        let nonAdjacentTransition = state.beginTransition(to: "p2")
        #expect(nonAdjacentTransition == nil)
        #expect(state == before)
    }

    @Test
    func transientEmptyUpdateCannotExposeAnEmptyViewportMidTransition() throws {
        var state = PagerStateMachine(
            pageIDs: ["p0", "p1"],
            committedID: "p0"
        )
        let tokenCandidate = state.beginTransition(to: "p1")
        let token = try #require(tokenCandidate)

        let updateAccepted = state.updatePages([])
        #expect(updateAccepted)
        #expect(state.displayedOrder == ["p0", "p1"])
        #expect(state.pendingOrder == [])

        let resolved = state.resolveTransition(
            token: token,
            completed: false
        )
        #expect(resolved)
        #expect(state.displayedOrder == [])
        #expect(state.committedID == nil)
    }

    @Test
    func twentyAlternatingTransitionsKeepVisualAndCommittedIdentityAligned() throws {
        var state = PagerStateMachine(
            pageIDs: ["p0", "p1"],
            committedID: "p0"
        )

        for index in 0..<20 {
            let target = index.isMultiple(of: 2) ? "p1" : "p0"
            let tokenCandidate = state.beginTransition(to: target)
            let token = try #require(tokenCandidate)
            let resolved = state.resolveTransition(
                token: token,
                completed: true
            )
            #expect(resolved)
            #expect(state.committedID == target)
        }

        #expect(state.committedID == "p0")
        #expect(state.resolvedTransitionCount == 20)
    }

    @Test
    func cachePolicyRemainsBoundedForOneHundredPages() throws {
        let pages = (0..<100).map { "p\($0)" }
        let settled = PagerCachePolicy.liveIDs(
            pageIDs: pages,
            committedID: "p50",
            transition: nil
        )
        #expect(settled == ["p49", "p50", "p51"])

        var state = PagerStateMachine(
            pageIDs: pages,
            committedID: "p50"
        )
        let tokenCandidate = state.beginTransition(to: "p51")
        _ = try #require(tokenCandidate)
        let transitioning = PagerCachePolicy.liveIDs(
            pageIDs: pages,
            committedID: state.committedID,
            transition: state.transition
        )
        #expect(transitioning.count <= 4)
        #expect(transitioning.contains("p50"))
        #expect(transitioning.contains("p51"))
    }
}
