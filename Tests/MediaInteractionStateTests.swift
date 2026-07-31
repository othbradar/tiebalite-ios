import Testing
@testable import TiebaLite

struct MediaInteractionStateTests {
    @Test
    func minimumZoomHorizontalGestureBelongsToPager() {
        let session = MediaGestureSession.begin(
            mediaID: "small",
            capability: .minimumZoom,
            intent: .towardNext
        )

        #expect(session.owner == .pager)
    }

    @Test
    func zoomedInteriorGestureStaysWithZoomPageEvenAfterReachingBoundary() {
        let session = MediaGestureSession.begin(
            mediaID: "large",
            capability: MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .interior
            ),
            intent: .towardNext
        )

        let afterBoundaryChange = session.updatingCapability(
            MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .trailing
            )
        )

        #expect(session.owner == .zoomPage)
        #expect(afterBoundaryChange.owner == .zoomPage)
    }

    @Test
    func nextGestureAtMatchingZoomBoundaryMayBelongToPager() {
        let towardPrevious = MediaGestureSession.begin(
            mediaID: "large",
            capability: MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .leading
            ),
            intent: .towardPrevious
        )
        let towardContent = MediaGestureSession.begin(
            mediaID: "large",
            capability: MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .leading
            ),
            intent: .towardNext
        )

        #expect(towardPrevious.owner == .pager)
        #expect(towardContent.owner == .zoomPage)
    }

    @Test
    func ambiguousOrVerticalIntentNeverStartsPaging() {
        let session = MediaGestureSession.begin(
            mediaID: "small",
            capability: .minimumZoom,
            intent: .verticalOrAmbiguous
        )

        #expect(session.owner == .zoomPage)
    }

    @Test
    func committedDepartureResetsOnlyTheSourceMediaID() {
        var registry = MediaZoomStateRegistry<String>()
        registry.update(
            MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .trailing
            ),
            for: "large"
        )
        registry.update(.minimumZoom, for: "small")

        registry.resolveDeparture(
            sourceID: "large",
            targetID: "small",
            completed: true
        )

        #expect(registry.capability(for: "large") == .minimumZoom)
        #expect(registry.capability(for: "small") == .minimumZoom)
    }

    @Test
    func cancelledDeparturePreservesZoomAndNeverLeaksItToAnotherID() {
        var registry = MediaZoomStateRegistry<String>()
        let zoomed = MediaPageCapability(
            atMinimumZoom: false,
            horizontalBoundary: .interior
        )
        registry.update(zoomed, for: "large")

        registry.resolveDeparture(
            sourceID: "large",
            targetID: "small",
            completed: false
        )

        #expect(registry.capability(for: "large") == zoomed)
        #expect(registry.capability(for: "small") == .minimumZoom)
    }

    @Test
    func closingViewerClearsEveryPerIDCapability() {
        var registry = MediaZoomStateRegistry<String>()
        registry.update(
            MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .both
            ),
            for: "large"
        )
        registry.close()

        #expect(registry.trackedIDs.isEmpty)
        #expect(registry.capability(for: "large") == .minimumZoom)
    }
}
