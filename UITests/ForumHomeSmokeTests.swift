import XCTest

final class ForumHomeSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFixtureForumHomeOpensThreadAndPreservesListPosition() {
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)

        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsFirstRow, in: app)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        UITestHarness.scrollToHittable(.forumHomeSelectedRow, in: app)
        let before = UITestHarness.element(
            .forumHomeSelectedRow,
            in: app
        ).frame

        UITestHarness.tap(.forumHomeSelectedRow, in: app)
        UITestHarness.requirePresent(.forumThreadReaderScreen, in: app)
        UITestHarness.tapSystemBack(
            in: app,
            returningTo: .forumHomeSelectedRow
        )

        let returned = UITestHarness.element(.forumHomeSelectedRow, in: app)
        XCTAssertTrue(returned.isHittable)
        XCTAssertEqual(returned.frame.midY, before.midY, accuracy: 12)
    }

    @MainActor
    func testFixtureForumThreadLoadsFivePagesSubpostsAndMedia() {
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)

        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.scrollToHittable(.forumHomeSelectedRow, in: app)
        let forumRowFrame = UITestHarness.element(
            .forumHomeSelectedRow,
            in: app
        ).frame
        UITestHarness.tap(.forumHomeSelectedRow, in: app)
        UITestHarness.requirePresent(.forumThreadReaderScreen, in: app)

        let threadList = UITestHarness.element(
            .forumThreadReaderScroll,
            in: app
        )
        XCTAssertTrue(threadList.waitForExistence(timeout: 5))
        for _ in 0..<5 {
            threadList.swipeUp()
            UITestHarness.requirePresent(.forumThreadReaderScreen, in: app)
        }
        UITestHarness.scrollToHittable(
            .forumThreadLastPagePost,
            inside: .forumThreadReaderScroll,
            in: app
        )

        UITestHarness.scrollBackToHittable(
            .forumThreadImageAction,
            inside: .forumThreadReaderScroll,
            in: app
        )
        UITestHarness.requirePresent(.forumThreadSubpost, in: app)
        UITestHarness.requireValue(
            .forumThreadImageAction,
            equals: "已加载",
            in: app
        )
        let imageFrame = UITestHarness.element(
            .forumThreadImageAction,
            in: app
        ).frame
        UITestHarness.tap(.forumThreadImageAction, in: app)
        UITestHarness.requirePresent(.mediaViewerRoot, in: app)
        MediaViewerProductionAssertions.requirePosition("1 / 1", in: app)
        UITestHarness.tap(.mediaViewerClose, in: app)
        UITestHarness.waitUntilAbsent(.mediaViewerRoot, in: app)
        let returnedImage = UITestHarness.element(
            .forumThreadImageAction,
            in: app
        )
        XCTAssertTrue(returnedImage.waitForExistence(timeout: 5))
        XCTAssertTrue(returnedImage.isHittable)
        XCTAssertEqual(returnedImage.frame.midY, imageFrame.midY, accuracy: 8)

        UITestHarness.tapSystemBack(
            in: app,
            returningTo: .forumHomeSelectedRow
        )
        let returned = UITestHarness.element(.forumHomeSelectedRow, in: app)
        XCTAssertTrue(returned.isHittable)
        XCTAssertEqual(returned.frame.midY, forumRowFrame.midY, accuracy: 12)
    }
}
