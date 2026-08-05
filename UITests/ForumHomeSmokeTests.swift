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
}
