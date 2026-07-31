import Testing
@testable import TiebaLite

struct ScaffoldEnvironmentTests {
    @Test
    func buildConfigurationLabelsAreSafeAndStable() {
        let expectations: [(ScaffoldEnvironment.BuildConfiguration, String)] = [
            (.debug, "Debug"),
            (.release, "Release"),
            (.uiTesting, "UITesting")
        ]

        for (configuration, expectedLabel) in expectations {
            #expect(configuration.displayName == expectedLabel)
        }
    }

    @Test
    func launchCopyIsStaticAndNonSensitive() {
        #expect(ScaffoldEnvironment.appName == "TiebaLite")
        #expect(ScaffoldEnvironment.statusText == "Design system and app shell")
        #expect(ScaffoldEnvironment.platformText == "iOS & iPadOS 18+")
    }

    @Test
    func unitTestsUseTheUITestingBuildConfiguration() {
        #expect(ScaffoldEnvironment.currentBuildConfiguration == .uiTesting)
    }
}
