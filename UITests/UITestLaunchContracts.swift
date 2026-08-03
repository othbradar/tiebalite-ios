enum UITestLaunchScenario: String, CaseIterable {
    case emptyShell = "app.empty-shell"
    case fixtureReadingFlow = "fixture.reading-flow"
    case networkOffline = "network.offline"
    case networkSlow = "network.slow"
    case threadContentRenderer = "renderer.thread-content"
    case sessionSignedOut = "session.signed-out"
    case sessionSignedInFixture = "session.signed-in-fixture"
    case sessionExpired = "session.expired"

    var safeLabel: String {
        switch self {
        case .emptyShell:
            "Harness: Empty shell"
        case .fixtureReadingFlow:
            "Harness: Fixture reading flow"
        case .networkOffline:
            "Harness: Network offline"
        case .networkSlow:
            "Harness: Network slow"
        case .threadContentRenderer:
            "Harness: Thread content renderer"
        case .sessionSignedOut:
            "Harness: Session signed out"
        case .sessionSignedInFixture:
            "Harness: Session signed in fixture"
        case .sessionExpired:
            "Harness: Session expired"
        }
    }
}

enum UITestDisplayProfile: String {
    case darkAccessibilityMaximumReduced = "dark-accessibility-maximum-reduced"
    case darkAccessibilityReduced = "dark-accessibility-reduced"
    case system
}

enum UITestAppTab {
    case followedForums
    case recommendations
    case settings

    var elementID: UITestElementID {
        switch self {
        case .recommendations:
            .tabRecommendations
        case .followedForums:
            .tabFollowedForums
        case .settings:
            .tabSettings
        }
    }
}
