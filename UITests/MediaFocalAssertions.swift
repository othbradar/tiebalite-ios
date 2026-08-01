import XCTest

enum MediaFocalAssertions {
    static func requireNonCenteredRetainedFocalPoint(
        _ snapshot: MediaUILayoutSnapshot,
        context: String
    ) {
        let displacement = max(
            abs(snapshot.retainedFocalPoint.x - 0.5),
            abs(snapshot.retainedFocalPoint.y - 0.5)
        )
        XCTAssertGreaterThan(
            displacement,
            0.04,
            "\(context) retained focal was centered: \(snapshot)"
        )
    }

    static func requireFocalPointPreserved(
        in snapshot: MediaUILayoutSnapshot,
        expectedRetained: MediaUIFocalPoint,
        context: String
    ) {
        XCTAssertEqual(
            snapshot.retainedFocalPoint.x,
            expectedRetained.x,
            accuracy: 0.02,
            "\(context) retained focal X"
        )
        XCTAssertEqual(
            snapshot.retainedFocalPoint.y,
            expectedRetained.y,
            accuracy: 0.02,
            "\(context) retained focal Y"
        )
        let expectedVisible = expectedVisibleFocalPoint(
            retained: expectedRetained,
            in: snapshot
        )
        XCTAssertEqual(
            snapshot.visibleFocalPoint.x,
            expectedVisible.x,
            accuracy: 0.02,
            "\(context) visible focal X"
        )
        XCTAssertEqual(
            snapshot.visibleFocalPoint.y,
            expectedVisible.y,
            accuracy: 0.02,
            "\(context) visible focal Y"
        )
    }

    private static func expectedVisibleFocalPoint(
        retained: MediaUIFocalPoint,
        in snapshot: MediaUILayoutSnapshot
    ) -> MediaUIFocalPoint {
        let desiredX = retained.x * snapshot.contentWidth
            - snapshot.viewportWidth / 2
        let desiredY = retained.y * snapshot.contentHeight
            - snapshot.viewportHeight / 2
        let offsetX = min(
            snapshot.maximumOffsetX,
            max(snapshot.minimumOffsetX, desiredX)
        )
        let offsetY = min(
            snapshot.maximumOffsetY,
            max(snapshot.minimumOffsetY, desiredY)
        )
        return MediaUIFocalPoint(
            x: (offsetX + snapshot.viewportWidth / 2)
                / snapshot.contentWidth,
            y: (offsetY + snapshot.viewportHeight / 2)
                / snapshot.contentHeight
        )
    }
}
