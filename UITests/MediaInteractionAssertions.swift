import XCTest

struct MediaUILayoutSnapshot: Equatable {
    let layoutGeneration: Int
    let viewportWidth: Double
    let viewportHeight: Double
    let contentWidth: Double
    let contentHeight: Double
    let minimumOffsetX: Double
    let maximumOffsetX: Double
    let minimumOffsetY: Double
    let maximumOffsetY: Double
    let visibleFocalPoint: MediaUIFocalPoint
    let retainedFocalPoint: MediaUIFocalPoint
    let imageFrameWidth: Double
    let imageFrameHeight: Double
    let coordinatorSequence: Int
    let invalidViewportCount: Int
    let chromeLayoutGeneration: Int
    let invalidChromeCount: Int
}

struct MediaUIFocalPoint: Equatable {
    let x: Double
    let y: Double
}

struct MediaUISessionSnapshot: Equatable {
    let sessionID: Int
    let mediaID: String?
    let totalPanBeginCount: Int
    let totalPanEndCount: Int
}

enum MediaInteractionAssertions {
    @MainActor
    static func stableLayout(
        in app: XCUIApplication,
        context: String = "stable"
    ) throws -> MediaUILayoutSnapshot {
        let viewer = UITestHarness.element(.interactionMediaViewer, in: app)
        let chrome = UITestHarness.element(.interactionMediaChrome, in: app)
        XCTAssertTrue(viewer.waitForExistence(timeout: 5))
        XCTAssertTrue(chrome.waitForExistence(timeout: 5))
        let predicate = NSPredicate { _, _ in
            guard let snapshot = try? layoutSnapshot(in: app) else {
                return false
            }
            return snapshot.layoutGeneration > 0
                && snapshot.chromeLayoutGeneration > 0
                && value(of: viewer).contains("valid=true")
                && value(of: chrome).contains("valid=true")
        }
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: viewer
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(
            result,
            .completed,
            "Viewer: \(value(of: viewer)); chrome: \(value(of: chrome))"
        )
        let snapshot = try layoutSnapshot(in: app)
        XCTAssertEqual(
            snapshot.invalidViewportCount,
            0,
            "\(context) viewer: \(value(of: viewer))"
        )
        XCTAssertEqual(
            snapshot.invalidChromeCount,
            0,
            "\(context) chrome: \(value(of: chrome))"
        )
        return snapshot
    }

    @MainActor
    static func requireLayoutTransition(
        in app: XCUIApplication,
        after previous: MediaUILayoutSnapshot,
        landscape: Bool
    ) throws -> MediaUILayoutSnapshot {
        let viewer = UITestHarness.element(.interactionMediaViewer, in: app)
        let chrome = UITestHarness.element(.interactionMediaChrome, in: app)
        let predicate = NSPredicate { _, _ in
            guard let snapshot = try? layoutSnapshot(in: app) else {
                return false
            }
            let orientationMatches = landscape
                ? snapshot.viewportWidth > snapshot.viewportHeight
                : snapshot.viewportHeight > snapshot.viewportWidth
            return snapshot.layoutGeneration > previous.layoutGeneration
                && snapshot.chromeLayoutGeneration
                    > previous.chromeLayoutGeneration
                && snapshot.coordinatorSequence
                    == previous.coordinatorSequence
                && snapshot.invalidViewportCount
                    == previous.invalidViewportCount
                && snapshot.invalidChromeCount
                    == previous.invalidChromeCount
                && orientationMatches
                && value(of: viewer).contains("valid=true")
                && value(of: chrome).contains("valid=true")
        }
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: viewer
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 8)
        XCTAssertEqual(
            result,
            .completed,
            "Viewer: \(value(of: viewer)); chrome: \(value(of: chrome))"
        )
        let snapshot = try layoutSnapshot(in: app)
        requireChromeControlsInsideChrome(in: app)
        return snapshot
    }

    @MainActor
    static func sessionSnapshot(
        in app: XCUIApplication
    ) throws -> MediaUISessionSnapshot {
        let owner = UITestHarness.element(.interactionMediaOwner, in: app)
        let zoom = UITestHarness.element(.interactionMediaZoom, in: app)
        return MediaUISessionSnapshot(
            sessionID: optionalInteger(
                named: "session",
                in: value(of: owner)
            ) ?? 0,
            mediaID: optionalToken(named: "media", in: value(of: owner)),
            totalPanBeginCount: try integer(
                named: "totalPanBegin",
                in: value(of: zoom)
            ),
            totalPanEndCount: try integer(
                named: "totalPanEnd",
                in: value(of: zoom)
            )
        )
    }

    @MainActor
    static func requireSessionAdvance(
        in app: XCUIApplication,
        after previous: MediaUISessionSnapshot,
        owner expectedOwner: String,
        mediaID expectedMediaID: String,
        requireMediaPanCounters: Bool
    ) throws -> MediaUISessionSnapshot {
        let owner = UITestHarness.element(.interactionMediaOwner, in: app)
        let predicate = NSPredicate { _, _ in
            guard let snapshot = try? sessionSnapshot(in: app) else {
                return false
            }
            let expectedPanDelta = requireMediaPanCounters ? 1 : 0
            let countersMatch = snapshot.totalPanBeginCount
                    == previous.totalPanBeginCount + expectedPanDelta
                && snapshot.totalPanEndCount
                    == previous.totalPanEndCount + expectedPanDelta
            return snapshot.sessionID == previous.sessionID + 1
                && snapshot.mediaID == expectedMediaID
                && countersMatch
                && owner.label == "Owner: \(expectedOwner)"
                && value(of: owner).contains("phase=ended")
        }
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: owner
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(
            result,
            .completed,
            "Owner: \(owner.label), value: \(value(of: owner))"
        )
        return try sessionSnapshot(in: app)
    }

    @MainActor
    static func requireChromeControlsInsideChrome(in app: XCUIApplication) {
        let chrome = UITestHarness.element(.interactionMediaChrome, in: app)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(
            window.frame.insetBy(dx: -0.5, dy: -0.5).contains(chrome.frame)
        )
        let identifiers = [
            "interaction.media.close",
            "interaction.media.accessibility.previous",
            "interaction.media.accessibility.next"
        ]
        for identifier in identifiers {
            let control = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(control.waitForExistence(timeout: 5))
            XCTAssertGreaterThan(control.frame.width, 0)
            XCTAssertGreaterThan(control.frame.height, 0)
            XCTAssertTrue(
                chrome.frame.insetBy(dx: -0.5, dy: -0.5)
                    .contains(control.frame)
            )
            XCTAssertTrue(control.isHittable)
        }
    }

    @MainActor
    static func integerMetric(
        named name: String,
        from identifier: UITestElementID,
        in app: XCUIApplication
    ) throws -> Int {
        try integer(
            named: name,
            in: value(of: UITestHarness.element(identifier, in: app))
        )
    }

    @MainActor
    static func zoomScale(in app: XCUIApplication) throws -> Double {
        let zoom = UITestHarness.element(.interactionMediaZoom, in: app)
        XCTAssertTrue(zoom.waitForExistence(timeout: 5))
        let prefix = "Zoom: "
        guard zoom.label.hasPrefix(prefix) else {
            XCTFail("Invalid zoom label: \(zoom.label)")
            return .nan
        }
        return try XCTUnwrap(Double(zoom.label.dropFirst(prefix.count)))
    }

    @MainActor
    private static func layoutSnapshot(
        in app: XCUIApplication
    ) throws -> MediaUILayoutSnapshot {
        let viewerText = value(
            of: UITestHarness.element(.interactionMediaViewer, in: app)
        )
        let chromeText = value(
            of: UITestHarness.element(.interactionMediaChrome, in: app)
        )
        let viewport = try pair(named: "viewport", in: viewerText)
        let content = try pair(named: "content", in: viewerText)
        let visibleFocal = try coordinate(named: "focal", in: viewerText)
        let retainedFocal = try coordinate(named: "retained", in: viewerText)
        let imageFrame = try pair(named: "frame", in: viewerText)
        let legalX = try range(named: "legalX", in: viewerText)
        let legalY = try range(named: "legalY", in: viewerText)
        return MediaUILayoutSnapshot(
            layoutGeneration: try integer(named: "layout", in: viewerText),
            viewportWidth: viewport.0,
            viewportHeight: viewport.1,
            contentWidth: content.0,
            contentHeight: content.1,
            minimumOffsetX: legalX.0,
            maximumOffsetX: legalX.1,
            minimumOffsetY: legalY.0,
            maximumOffsetY: legalY.1,
            visibleFocalPoint: MediaUIFocalPoint(
                x: visibleFocal.0,
                y: visibleFocal.1
            ),
            retainedFocalPoint: MediaUIFocalPoint(
                x: retainedFocal.0,
                y: retainedFocal.1
            ),
            imageFrameWidth: imageFrame.0,
            imageFrameHeight: imageFrame.1,
            coordinatorSequence: try integer(
                named: "coordinator",
                in: viewerText
            ),
            invalidViewportCount: try integer(
                named: "invalidViewport",
                in: viewerText
            ),
            chromeLayoutGeneration: try integer(
                named: "chromeLayout",
                in: chromeText
            ),
            invalidChromeCount: try integer(
                named: "invalidChrome",
                in: chromeText
            )
        )
    }

    private static func integer(named name: String, in text: String) throws -> Int {
        let value = try token(named: name, in: text)
        return try XCTUnwrap(Int(value), "Invalid integer metric: \(name)")
    }

    private static func optionalInteger(named name: String, in text: String) -> Int? {
        let prefix = "\(name)="
        let component = text.split(separator: " ").first {
            $0.hasPrefix(prefix)
        }
        return component.flatMap {
            Int($0.dropFirst(prefix.count))
        }
    }

    private static func optionalToken(
        named name: String,
        in text: String
    ) -> String? {
        let prefix = "\(name)="
        let component = text.split(separator: " ").first {
            $0.hasPrefix(prefix)
        }
        return component.map { String($0.dropFirst(prefix.count)) }
    }

    private static func pair(
        named name: String,
        in text: String
    ) throws -> (Double, Double) {
        let components = try token(named: name, in: text).split(separator: "x")
        XCTAssertEqual(components.count, 2)
        let first = try XCTUnwrap(components.first.flatMap { Double($0) })
        let last = try XCTUnwrap(components.last.flatMap { Double($0) })
        return (first, last)
    }

    private static func range(
        named name: String,
        in text: String
    ) throws -> (Double, Double) {
        let components = try token(named: name, in: text)
            .components(separatedBy: "...")
        XCTAssertEqual(components.count, 2)
        let first = try XCTUnwrap(components.first.flatMap(Double.init))
        let last = try XCTUnwrap(components.last.flatMap(Double.init))
        return (first, last)
    }

    private static func coordinate(
        named name: String,
        in text: String
    ) throws -> (Double, Double) {
        let components = try token(named: name, in: text).split(separator: ",")
        XCTAssertEqual(components.count, 2)
        let first = try XCTUnwrap(components.first.flatMap { Double($0) })
        let last = try XCTUnwrap(components.last.flatMap { Double($0) })
        return (first, last)
    }

    private static func token(named name: String, in text: String) throws -> String {
        let prefix = "\(name)="
        let component = text.split(separator: " ").first {
            $0.hasPrefix(prefix)
        }
        return try XCTUnwrap(component.map { String($0.dropFirst(prefix.count)) })
    }

    @MainActor
    private static func value(of element: XCUIElement) -> String {
        element.value as? String ?? ""
    }
}
