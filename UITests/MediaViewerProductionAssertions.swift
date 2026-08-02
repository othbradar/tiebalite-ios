import XCTest

@MainActor
enum MediaViewerProductionAssertions {
    static let mediaIDs = (0..<6).map {
        "t93001.p94001.sfirstPost.n\($0)"
    }

    static func openRendererLab(in app: XCUIApplication) {
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(
            .debugOpenThreadContentRenderer,
            in: app
        )
        UITestHarness.tap(.debugOpenThreadContentRenderer, in: app)
        UITestHarness.requirePresent(.threadContentLabRoot, in: app)
    }

    static func openSingle(in app: XCUIApplication) {
        UITestHarness.scrollBackToHittable(
            .mediaViewerOpenSingle,
            in: app
        )
        UITestHarness.tap(.mediaViewerOpenSingle, in: app)
        UITestHarness.requirePresent(.mediaViewerRoot, in: app)
        requirePosition("1 / 1", in: app)
        _ = requireImage(at: 0, in: app)
    }

    static func openMultiple(in app: XCUIApplication) {
        UITestHarness.scrollBackToHittable(
            .mediaViewerOpenMultiple,
            in: app
        )
        UITestHarness.tap(.mediaViewerOpenMultiple, in: app)
        UITestHarness.requirePresent(.mediaViewerRoot, in: app)
        requirePosition("1 / 6", in: app)
        _ = requireImage(at: 0, in: app)
    }

    static func close(in app: XCUIApplication) {
        UITestHarness.tap(.mediaViewerClose, in: app)
        UITestHarness.waitUntilAbsent(.mediaViewerRoot, in: app)
        UITestHarness.requirePresent(.threadContentLabRoot, in: app)
    }

    static func requirePosition(
        _ expected: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        UITestHarness.requireLabel(
            .mediaViewerPosition,
            equals: expected,
            in: app,
            file: file,
            line: line
        )
    }

    @discardableResult
    static func requireImage(
        at index: Int,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let element = app.descendants(matching: .any)[
            "media-viewer.image.\(mediaIDs[index])"
        ]
        guard element.waitForExistence(timeout: 5) else {
            UITestHarness.attachSafeVisualEvidence(
                app: app,
                name: "Missing production media image \(index)"
            )
            XCTFail(
                "Missing production media image \(index)",
                file: file,
                line: line
            )
            return element
        }
        let predicate = NSPredicate(format: "hittable == true")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            UITestHarness.attachSafeVisualEvidence(
                app: app,
                name: "Production media image not visible \(index)"
            )
            XCTFail(
                "Production media image is cached but not visible \(index)",
                file: file,
                line: line
            )
            return element
        }
        return element
    }

    @discardableResult
    static func requireState(
        at index: Int,
        component: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let identifier =
            "media-viewer.state.\(mediaIDs[index]).\(component)"
        let element = app.descendants(matching: .any)[identifier]
        guard element.waitForExistence(timeout: 5) else {
            UITestHarness.attachSafeVisualEvidence(
                app: app,
                name: "Missing production media state \(component)"
            )
            XCTFail(
                "Missing production media state \(component)",
                file: file,
                line: line
            )
            return element
        }
        let pager = app.descendants(matching: .any)[
            UITestElementID.mediaViewerPager.rawValue
        ]
        let predicate = NSPredicate { _, _ in
            guard pager.exists else {
                return false
            }
            let frame = element.frame
            let pagerFrame = pager.frame
            return abs(frame.minX - pagerFrame.minX) <= 1
                && abs(frame.minY - pagerFrame.minY) <= 1
                && abs(frame.width - pagerFrame.width) <= 1
                && abs(frame.height - pagerFrame.height) <= 1
        }
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            UITestHarness.attachSafeVisualEvidence(
                app: app,
                name: "Production media state not current \(component)"
            )
            XCTFail(
                "Production media state exists only as an offscreen page: "
                    + component,
                file: file,
                line: line
            )
            return element
        }
        return element
    }

    static func requireChromeVisible(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let close = app.descendants(matching: .any)[
            UITestElementID.mediaViewerClose.rawValue
        ]
        let predicate = NSPredicate(format: "hittable == true")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: close
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            UITestHarness.attachSafeVisualEvidence(
                app: app,
                name: "Production MediaViewer chrome unavailable"
            )
            XCTFail(
                "Production MediaViewer has no reachable close control",
                file: file,
                line: line
            )
            return
        }
    }

    static func requireZoomed(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(
            format: "value BEGINSWITH %@",
            "已放大"
        )
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            XCTFail("Media image did not enter zoomed state", file: file, line: line)
            return
        }
    }

    static func requireOriginalSize(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "value == %@", "原始大小")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            XCTFail("Media image did not reset zoom", file: file, line: line)
            return
        }
    }
}
