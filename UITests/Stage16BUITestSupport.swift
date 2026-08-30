import XCTest

enum Stage16BUITestID {
    static let appearancePicker = "settings.appearance"
    static let historyClear = "history.clear"
    static let historyList = "history.list"
    static let historyScreen = "history.screen"
    static let openHistory = "settings.open-history"
    static let readingSizePicker = "settings.reading-text-size"
    static let settingsClearHistory = "settings.clear-history"
    static let threadAuthor = "thread-reader.author.1100003"
    static let threadFirstText =
        "thread-reader.content.node.t100003.p110003.sfirstPost.n0"
    static let threadHistoryRow = "history.row.thread.100003"
    static let userHistoryRow = "history.row.user.1100003"
    static let userProfile = "user-profile.facts.1100003"
}

enum Stage16BUITestSupport {
    enum ScrollDirection {
        case down
        case up
    }

    @MainActor
    static func element(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    static func requirePresent(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let candidate = element(identifier, in: app)
        guard candidate.waitForExistence(timeout: 5) else {
            attachFailure(app: app, expected: identifier)
            XCTFail(
                "Missing Stage 16B fixture element: \(identifier)",
                file: file,
                line: line
            )
            return candidate
        }
        return candidate
    }

    @MainActor
    static func tap(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let candidate = requirePresent(
            identifier,
            in: app,
            file: file,
            line: line
        )
        guard candidate.isHittable else {
            attachFailure(app: app, expected: identifier)
            XCTFail(
                "Stage 16B fixture element is not hittable: \(identifier)",
                file: file,
                line: line
            )
            return
        }
        candidate.tap()
    }

    @MainActor
    static func scrollToHittable(
        _ identifier: String,
        inside containerIdentifier: String,
        direction: ScrollDirection = .up,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let candidate = element(identifier, in: app)
        let container = requirePresent(
            containerIdentifier,
            in: app,
            file: file,
            line: line
        )
        for _ in 0..<16 {
            if candidate.exists, candidate.isHittable {
                return candidate
            }
            switch direction {
            case .down:
                container.swipeDown()
            case .up:
                container.swipeUp()
            }
        }
        attachFailure(app: app, expected: identifier)
        XCTFail(
            "Stage 16B scroll target is not hittable: \(identifier)",
            file: file,
            line: line
        )
        return candidate
    }

    @MainActor
    static func selectSegment(
        _ label: String,
        pickerIdentifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let picker = requirePresent(
            pickerIdentifier,
            in: app,
            file: file,
            line: line
        )
        let nested = picker.buttons[label].firstMatch
        let segment = nested.exists ? nested : app.buttons[label].firstMatch
        guard segment.waitForExistence(timeout: 5), segment.isHittable else {
            attachFailure(app: app, expected: pickerIdentifier)
            XCTFail(
                "Missing settings segment: \(label)",
                file: file,
                line: line
            )
            return
        }
        segment.tap()
        let selected = NSPredicate(format: "selected == true")
        let expectation = XCTNSPredicateExpectation(
            predicate: selected,
            object: segment
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed,
            file: file,
            line: line
        )
    }

    @MainActor
    static func tapSystemBack(
        returningTo identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        guard button.waitForExistence(timeout: 5), button.isHittable else {
            attachFailure(app: app, expected: identifier)
            XCTFail(
                "System back is unavailable",
                file: file,
                line: line
            )
            return
        }
        button.tap()
        _ = requirePresent(identifier, in: app, file: file, line: line)
    }

    @MainActor
    static func requireAbsent(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let candidate = element(identifier, in: app)
        let absent = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(
            predicate: absent,
            object: candidate
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed,
            file: file,
            line: line
        )
    }

    @MainActor
    private static func attachFailure(
        app: XCUIApplication,
        expected: String
    ) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Stage 16B missing fixture: \(expected)"
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Attach Stage 16B fixture evidence") {
            $0.add(attachment)
        }
    }
}
