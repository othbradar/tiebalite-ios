import XCTest

final class R04FeedSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFlatFeedMediaPaginationAndReturnPosition() {
        executionTimeAllowance = 120
        let app = UITestHarness.launch(scenario: .dynamicFeedParity)
        UITestHarness.requirePresent(.recommendationsFirstRow, in: app)
        UITestHarness.requireAbsent(.shellTitle, in: app)
        requireValue("已加载", element: app.descendants(matching: .any)["recommendations.avatar.t100001"])
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R04 plain and single image")
        UITestHarness.scrollToHittable(.recommendationsSelectedRow, inside: .recommendationsList, in: app)
        let selected = app.buttons[UITestElementID.recommendationsSelectedRow.rawValue]
        requireValue("已加载", element: app.descendants(matching: .any)["recommendations.avatar.t100003"])
        for index in 0..<3 {
            let media = app.descendants(matching: .any)["tieba.media-grid.r04.t100003.media.\(index)"]
            XCTAssertTrue(media.waitForExistence(timeout: 5))
            requireValue("已加载", element: media)
        }
        XCTAssertFalse(app.descendants(matching: .any)["tieba.media-grid.r04.t100003.media.3"].exists)
        let count = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "共 8 张图片")).firstMatch
        XCTAssertTrue(count.exists)
        let before = selected.frame
        selected.tap()
        UITestHarness.requirePresent(.threadReaderScreen, in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .recommendationsRoot)
        XCTAssertTrue(selected.isHittable)
        XCTAssertEqual(selected.frame.midY, before.midY, accuracy: 12)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R04 multi image return")
        UITestHarness.scrollToHittable(.recommendationsAvatarFailureRow, inside: .recommendationsList, in: app)
        let failedAvatar = app.descendants(matching: .any)["recommendations.avatar.t100009"]
        requireValue("加载失败", element: failedAvatar)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R04 avatar failure and two images")
        UITestHarness.scrollToHittable(.recommendationsLastPageRow, inside: .recommendationsList, in: app)
        let last = UITestHarness.element(.recommendationsLastPageRow, in: app)
        let lastFrame = last.frame
        for tab in [UITestAppTab.followedForums, .notifications, .settings, .recommendations] {
            UITestHarness.tapTab(tab, in: app)
            UITestHarness.requireTabSelected(tab, in: app)
        }
        UITestHarness.requirePresent(.recommendationsRoot, in: app)
        XCTAssertTrue(last.isHittable)
        XCTAssertEqual(last.frame.midY, lastFrame.midY, accuracy: 12)
        UITestHarness.scrollBackToHittable(.recommendationsFirstRow, inside: .recommendationsList, in: app)
        UITestHarness.requirePresent(.recommendationsFirstRow, in: app)
    }

    @MainActor
    private func requireValue(_ value: String, element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
