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
        UITestHarness.requireAbsent(.root, in: app)
    }

    @MainActor
    private func assertPlaceholder(for scenario: UITestLaunchScenario) {
        let app = UITestHarness.launch(scenario: scenario)

        UITestHarness.requirePresent(.root, in: app)
        UITestHarness.requirePresent(.title, in: app)
        UITestHarness.requirePresent(.environment, in: app)
        UITestHarness.requirePresent(
            .scenario,
            in: app,
            expectedLabel: scenario.safeLabel
        )
        UITestHarness.requireAbsent(.invalidScenario, in: app)
    }
}
