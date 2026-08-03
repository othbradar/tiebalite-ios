import XCTest

final class LaunchSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyShellScenario() {
        assertPlaceholder(for: .emptyShell)
    }

    @MainActor
    func testOfflineScenario() {
        assertPlaceholder(for: .networkOffline)
    }

    @MainActor
    func testSlowNetworkScenario() {
        assertPlaceholder(for: .networkSlow)
    }

    @MainActor
    func testSignedOutScenario() {
        assertPlaceholder(for: .sessionSignedOut)
    }

    @MainActor
    func testSignedInFixtureScenario() {
        assertPlaceholder(for: .sessionSignedInFixture)
    }

    @MainActor
    func testExpiredSessionScenario() {
        assertPlaceholder(for: .sessionExpired)
    }

    @MainActor
    func testUnknownScenarioFailsClosed() {
        let app = UITestHarness.launchUnknownScenarioCanary()

        UITestHarness.requirePresent(
            .invalidScenario,
            in: app,
            expectedLabel: "invalid-scenario"
        )
        UITestHarness.requireAbsent(.shellRoot, in: app)
    }

    @MainActor
    private func assertPlaceholder(for scenario: UITestLaunchScenario) {
        let app = UITestHarness.launch(scenario: scenario)

        UITestHarness.requirePresent(.shellRoot, in: app)
        UITestHarness.requirePresent(.shellTitle, in: app)
        UITestHarness.requirePresent(.recommendationsRoot, in: app)
        UITestHarness.requireTabPresent(.recommendations, in: app)
        UITestHarness.requireTabPresent(.followedForums, in: app)
        UITestHarness.requireTabPresent(.settings, in: app)
        UITestHarness.requirePresent(
            .shellScenario,
            in: app,
            expectedLabel: scenario.safeLabel
        )
        UITestHarness.requireAbsent(.invalidScenario, in: app)
    }
}
