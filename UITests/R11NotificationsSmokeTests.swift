import XCTest

final class R11NotificationsSmokeTests: XCTestCase {
    @MainActor
    func testThemeQuoteOpensThreadWhileReplyOpensExactFloor() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture, startingTab: .notifications)
        let list = app.tables["notifications.list.replies"]
        let replyID = "notifications.row.replies.9001.101.1700000001"
        let reply = app.buttons[replyID]
        let reader = app.tables["thread-reader.scroll.t8001"]
        for attempt in 1...3 {
            guard list.waitForExistence(timeout: 5), reply.waitForExistence(timeout: 5) else {
                XCTFail("Missing reply list before attempt \(attempt)"); return
            }
            let cell = list.cells.containing(.button, identifier: replyID).firstMatch
            let savedY = cell.frame.midY
            // The quote occupies the lower part of this fixed, short fixture row.
            cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.84)).tap()
            guard reader.waitForExistence(timeout: 5) else { XCTFail("Quote did not open thread"); return }
            XCTAssertTrue(app.textViews["thread-reader.content.node.t8001.p18001.sfirstPost.n0"].exists,
                          "Quote must show the thread's first post, attempt \(attempt)")
            XCTAssertTrue(app.textViews["thread-reader.content.node.t8001.p18001.sfirstPost.n0"].isHittable)
            XCTAssertLessThan(app.textViews["thread-reader.content.node.t8001.p18001.sfirstPost.n0"].frame.minY,
                              reader.frame.minY + 180, "Quote must start with the first post")
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R11 quote destination \(attempt)")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(list.waitForExistence(timeout: 5))
            XCTAssertEqual(cell.frame.midY, savedY, accuracy: 12)
            reply.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
            guard reader.waitForExistence(timeout: 5) else { XCTFail("Reply did not open target"); return }
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R11 actual target before scrolling \(attempt)")
            let hierarchy = XCTAttachment(string: reader.debugDescription)
            hierarchy.name = "R11 fixture target hierarchy \(attempt)"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let target = reader.textViews["thread-reader.content.node.t8001.p9001.spost.n0"]
            XCTAssertTrue(target.isHittable)
            XCTAssertLessThan(target.frame.minY, reader.frame.minY + 180, "Reply must scroll near the top")
            let firstPost = app.textViews["thread-reader.content.node.t8001.p18001.sfirstPost.n0"]
            for _ in 0..<5 {
                if firstPost.exists, !firstPost.frame.isEmpty, reader.frame.contains(firstPost.frame), firstPost.isHittable { break }
                reader.swipeDown()
            }
            XCTAssertTrue(firstPost.isHittable, "Target must retain earlier floors, attempt \(attempt)")
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R11 target scroll back to first post \(attempt)")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(list.waitForExistence(timeout: 5))
            XCTAssertEqual(cell.frame.midY, savedY, accuracy: 12)
        }
    }

    @MainActor
    func testRepliesMentionsPagingTargetsAndReturnPosition() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)
        UITestHarness.tapTab(.notifications, in: app)
        let replies = app.tables["notifications.list.replies"]
        XCTAssertTrue(replies.waitForExistence(timeout: 5))
        let first = app.buttons["notifications.row.replies.9001.101.1700000001"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        let reader = app.tables["thread-reader.scroll.t8001"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["thread-reader.content.node.t8001.p9001.spost.n0"].exists)
        XCTAssertFalse(app.buttons[UITestElementID.tabNotifications.rawValue].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(replies.waitForExistence(timeout: 5))
        app.buttons["notifications.row.replies.10001.102.1700000002"].tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["thread-reader.content.node.t8001.p9002.spost.n0"].isHittable)
        XCTAssertFalse(app.tables["subposts.list"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let middle = app.buttons["notifications.row.replies.9018.118.1700000018"]
        reveal(middle, in: replies)
        let savedY = middle.frame.midY
        replies.swipeLeft()
        let mentions = app.tables["notifications.list.mentions"]
        XCTAssertTrue(mentions.waitForExistence(timeout: 5) && mentions.isHittable)
        XCTAssertTrue(app.buttons["notifications.tab.mentions"].isSelected)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R11 mentions and emoticons")
        mentions.swipeRight()
        XCTAssertTrue(app.buttons["notifications.tab.replies"].isSelected)
        XCTAssertTrue(middle.isHittable)
        XCTAssertEqual(middle.frame.midY, savedY, accuracy: 12)
        for tab in [UITestAppTab.followedForums, .recommendations, .settings, .notifications] {
            UITestHarness.tapTab(tab, in: app)
            UITestHarness.requireTabSelected(tab, in: app)
            switch tab {
            case .followedForums: XCTAssertTrue(app.buttons["home.search"].isHittable)
            case .recommendations: XCTAssertTrue(app.tables["recommendations.list"].isHittable)
            case .settings: UITestHarness.requirePresent(.personalRoot, in: app)
            case .notifications: XCTAssertTrue(replies.isHittable)
            }
        }
        XCTAssertTrue(middle.isHittable)
        XCTAssertEqual(middle.frame.midY, savedY, accuracy: 12)
        middle.tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["thread-reader.content.node.t8001.p9018.spost.n0"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(middle.isHittable)
        XCTAssertEqual(middle.frame.midY, savedY, accuracy: 12)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            UITestHarness.requirePresent(.layoutRegular, in: app)
            XCTAssertTrue(replies.isHittable)
            app.buttons["notifications.tab.mentions"].tap()
            XCTAssertTrue(mentions.isHittable)
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R11 iPad landscape mentions")
            XCUIDevice.shared.orientation = .portrait
            UITestHarness.requirePresent(.layoutCompact, in: app)
            app.buttons["notifications.tab.replies"].tap()
        }
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R11 replies middle")
    }

    @MainActor
    func testLastFollowedForumIsFullyAboveBottomNavigation() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .rootNavigationMixedMedia, startingTab: .followedForums)
        let list = app.tables["followed-forums.list"]
        let last = app.buttons["followed-forums.row.f14023"]
        let selector = app.buttons[UITestElementID.tabFollowedForums.rawValue]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        for _ in 0..<8 {
            if last.exists, !last.frame.isEmpty, list.frame.contains(last.frame), last.isHittable { break }
            list.swipeUp()
        }
        for attempt in 1...3 {
            list.swipeUp()
            XCTAssertTrue(last.isHittable)
            XCTAssertLessThanOrEqual(last.frame.maxY, selector.frame.minY - 1,
                                     "Attempt \(attempt): last=\(last.frame), list=\(list.frame), bar=\(selector.frame)")
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R11 home bottom \(attempt)")
            if attempt < 3 {
                list.swipeDown()
                list.swipeUp()
            }
        }
    }

    @MainActor private func reveal(_ row: XCUIElement, in list: XCUIElement) {
        for _ in 0..<14 {
            if row.exists, !row.frame.isEmpty, list.frame.contains(row.frame), row.isHittable { return }
            list.swipeUp()
        }
        XCTAssertTrue(row.isHittable)
    }
}
