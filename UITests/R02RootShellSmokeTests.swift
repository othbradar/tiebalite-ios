import XCTest

final class R02RootShellSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFourTabsAndIndependentPaths() {
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture, startingTab: nil)
        UITestHarness.requireTabSelected(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsFirstRow, in: app)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
        UITestHarness.requireAbsent(.tabFollowedForums, in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)

        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requireAbsent(.shellTitle, in: app)
        UITestHarness.scrollToHittable(
            .recommendationsSelectedRow, inside: .recommendationsList, in: app
        )
        UITestHarness.tap(.recommendationsSelectedRow, in: app)
        UITestHarness.requirePresent(.threadReaderScreen, in: app)
        UITestHarness.requireAbsent(.tabRecommendations, in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .recommendationsSelectedRow)

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.requirePresent(.personalRoot, in: app)
        UITestHarness.tap(.personalSettings, in: app)
        UITestHarness.requirePresent(.settingsRoot, in: app)

        UITestHarness.tapTab(.notifications, in: app)
        UITestHarness.requirePresent(.notificationsRoot, in: app)
        UITestHarness.requireTabSelected(.notifications, in: app)
        UITestHarness.requireAbsent(.settingsRoot, in: app)
        let messages = UITestHarness.element(.tabNotifications, in: app)
        XCTAssertTrue((messages.value as? String ?? "").contains("3 条未读消息"))
        UITestHarness.tapTab(.notifications, in: app)
        UITestHarness.requirePresent(.notificationsRoot, in: app)

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.requirePresent(.settingsRoot, in: app)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.recommendationsSelectedRow, in: app)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.recommendationsSelectedRow, in: app)
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsFirstRow, in: app)
    }

    @MainActor
    func testDynamicScrollSurvivesFourTabsAndMediaCoverRemainsSingle() {
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)
        UITestHarness.scrollToHittable(
            .recommendationsSelectedRow, inside: .recommendationsList, in: app
        )
        let before = UITestHarness.element(.recommendationsSelectedRow, in: app).frame
        for tab in [UITestAppTab.notifications, .settings, .followedForums, .recommendations] {
            UITestHarness.tapTab(tab, in: app)
        }
        let returned = UITestHarness.element(.recommendationsSelectedRow, in: app)
        XCTAssertTrue(returned.isHittable)
        XCTAssertEqual(returned.frame.midY, before.midY, accuracy: 12)
        UITestHarness.tap(.recommendationsSelectedRow, in: app)
        UITestHarness.scrollToHittable(
            .threadReaderImageSecondAction, inside: .threadReaderScreen, in: app
        )
        UITestHarness.requireValue(.threadReaderImageSecondAction, equals: "已加载", in: app)
        UITestHarness.tap(.threadReaderImageSecondAction, in: app)
        UITestHarness.requirePresent(.mediaViewerPager, in: app)
        XCTAssertEqual(app.descendants(matching: .any)
            .matching(identifier: UITestElementID.mediaViewerPager.rawValue).count, 1)
        UITestHarness.tap(.mediaViewerClose, in: app)
        UITestHarness.waitUntilAbsent(.mediaViewerPager, in: app)
        UITestHarness.requirePresent(.threadReaderScreen, in: app)
    }

    @MainActor
    func testDeepDynamicScrollAndRepeatedRootSwitchesStayResponsive() {
        executionTimeAllowance = 120
        let app = UITestHarness.launchIsolated(scenario: .rootNavigationMixedMedia)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.recommendationsFirstRow, in: app)
        for _ in 0..<2 {
            UITestHarness.scrollToHittable(
                .recommendationsLastPageRow, inside: .recommendationsList, in: app
            )
            let before = UITestHarness.element(.recommendationsLastPageRow, in: app).frame
            for tab in [UITestAppTab.notifications, .settings, .followedForums, .recommendations] {
                UITestHarness.tapTab(tab, in: app)
                UITestHarness.requireTabSelected(tab, in: app)
                requireRootVisible(tab, in: app)
            }
            let returned = UITestHarness.element(.recommendationsLastPageRow, in: app)
            XCTAssertTrue(returned.isHittable)
            XCTAssertEqual(returned.frame.midY, before.midY, accuracy: 12)
            UITestHarness.scrollBackToHittable(
                .recommendationsFirstRow, inside: .recommendationsList, in: app
            )
        }
        UITestHarness.tapTab(.notifications, in: app)
        UITestHarness.requirePresent(.notificationsRoot, in: app)
    }

    @MainActor
    func testIPadDynamicScrollSidebarAndWidthChangeKeepTheVisibleThread() {
        executionTimeAllowance = 120
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        defer { device.orientation = .portrait }
        let app = UITestHarness.launchIsolated(scenario: .rootNavigationMixedMedia)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.scrollToHittable(
            .recommendationsLastPageRow, inside: .recommendationsList,
            gestureAnchor: .recommendationsFirstRow, in: app
        )
        let before = UITestHarness.element(.recommendationsLastPageRow, in: app).frame
        let wideWidth = UITestHarness.element(.recommendationsList, in: app).frame.width
        for tab in [UITestAppTab.notifications, .settings, .followedForums, .recommendations] {
            UITestHarness.tapTab(tab, in: app)
            UITestHarness.requireTabSelected(tab, in: app)
            requireRootVisible(tab, in: app)
        }
        let returned = UITestHarness.element(.recommendationsLastPageRow, in: app)
        XCTAssertTrue(returned.isHittable)
        XCTAssertEqual(returned.frame.midY, before.midY, accuracy: 12)
        device.orientation = .portrait
        requireRootVisible(.recommendations, in: app)
        XCTAssertNotEqual(UITestHarness.element(.recommendationsList, in: app).frame.width, wideWidth)
        XCTAssertTrue(UITestHarness.element(.recommendationsLastPageRow, in: app).isHittable)
        UITestHarness.scrollBackToHittable(
            .recommendationsFirstRow, inside: .recommendationsList, in: app
        )
        UITestHarness.requirePresent(.recommendationsFirstRow, in: app)
    }

    @MainActor
    private func requireRootVisible(_ tab: UITestAppTab, in app: XCUIApplication) {
        let identifier: UITestElementID = switch tab {
        case .recommendations: .recommendationsRoot
        case .followedForums: .followedForumsRoot
        case .notifications: .notificationsRoot
        case .settings: .personalRoot
        }
        UITestHarness.requirePresent(identifier, in: app)
        XCTAssertTrue(UITestHarness.element(identifier, in: app).isHittable)
    }

    @MainActor
    func testIPadSidebarAndProjectionKeepAllFourRoutes() {
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        defer { device.orientation = .portrait }
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture, startingTab: nil)
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requireTabSelected(.followedForums, in: app)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.tap(.personalSettings, in: app)
        UITestHarness.requirePresent(.settingsRoot, in: app)
        UITestHarness.tapTab(.notifications, in: app)
        UITestHarness.requirePresent(.notificationsRoot, in: app)
        UITestHarness.requireAbsent(.settingsRoot, in: app)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.recommendationsRoot, in: app)
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
        UITestHarness.tap(.layoutControlCompact, in: app)
        UITestHarness.requirePresent(.layoutCompact, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
        UITestHarness.requireAbsent(.tabFollowedForums, in: app)
        UITestHarness.tap(.layoutControlRegular, in: app)
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.requirePresent(.settingsRoot, in: app)
        UITestHarness.tap(.layoutControlCompact, in: app)
        UITestHarness.requirePresent(.layoutCompact, in: app)
        UITestHarness.requirePresent(.settingsRoot, in: app)
        UITestHarness.tap(.layoutControlRegular, in: app)
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requirePresent(.settingsRoot, in: app)
    }
}
