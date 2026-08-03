import Foundation

#if UITESTING
import SwiftUI
#endif

#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
enum LaunchScenarioID: String, CaseIterable, Equatable, Sendable {
    case emptyShell = "app.empty-shell"
    case fixtureReadingFlow = "fixture.reading-flow"
    case networkOffline = "network.offline"
    case networkSlow = "network.slow"
    case threadContentRenderer = "renderer.thread-content"
    case sessionExpired = "session.expired"
    case sessionSignedInFixture = "session.signed-in-fixture"
    case sessionSignedOut = "session.signed-out"
}

enum LaunchScenarioParseError: Error, Equatable, Sendable {
    case duplicateFlag
    case missingFlag
    case missingValue
    case unknownIdentifier

    var safeDescription: String {
        switch self {
        case .duplicateFlag:
            "duplicate-scenario"
        case .missingFlag:
            "missing-scenario"
        case .missingValue:
            "missing-scenario-value"
        case .unknownIdentifier:
            "unknown-scenario"
        }
    }
}

enum LaunchScenarioParser {
    static let flag = "--launch-scenario"

    static func parse(arguments: [String]) throws -> LaunchScenarioID {
        let flagIndices = arguments.indices.filter { arguments[$0] == flag }
        guard !flagIndices.isEmpty else {
            throw LaunchScenarioParseError.missingFlag
        }
        guard flagIndices.count == 1 else {
            throw LaunchScenarioParseError.duplicateFlag
        }

        let valueIndex = flagIndices[0] + 1
        guard arguments.indices.contains(valueIndex) else {
            throw LaunchScenarioParseError.missingValue
        }
        guard let scenario = LaunchScenarioID(rawValue: arguments[valueIndex]) else {
            throw LaunchScenarioParseError.unknownIdentifier
        }
        return scenario
    }
}

enum LaunchScenarioRegistry {
    static let schemaVersion = 1
    static let isolationCanary = "TIEBALITE_TEST_SUPPORT_CANARY"
}

enum LaunchDisplayProfile: String, Equatable, Sendable {
    case darkAccessibilityMaximumReduced =
        "dark-accessibility-maximum-reduced"
    case darkAccessibilityReduced = "dark-accessibility-reduced"
    case system
}

enum LaunchDisplayProfileParser {
    static let flag = "--display-profile"

    static func parse(arguments: [String]) throws -> LaunchDisplayProfile {
        let flagIndices = arguments.indices.filter { arguments[$0] == flag }
        guard flagIndices.count <= 1 else {
            throw LaunchScenarioParseError.duplicateFlag
        }
        guard let flagIndex = flagIndices.first else {
            return .system
        }

        let valueIndex = flagIndex + 1
        guard arguments.indices.contains(valueIndex) else {
            throw LaunchScenarioParseError.missingValue
        }
        guard let profile = LaunchDisplayProfile(
            rawValue: arguments[valueIndex]
        ) else {
            throw LaunchScenarioParseError.unknownIdentifier
        }
        return profile
    }
}

enum LaunchScenarioNetworkMode: Equatable, Sendable {
    case controlled
    case offline
    case slow
}

@MainActor
struct LaunchScenarioDescriptor {
    let scenario: LaunchScenarioID
    let safeLabel: String
    let networkMode: LaunchScenarioNetworkMode
    let compositionRoot: AppCompositionRoot
    let isolationCanary: String
    let displayProfile: LaunchDisplayProfile
}

@MainActor
enum LaunchScenarioResolution {
    case invalid(code: String)
    case ready(LaunchScenarioDescriptor)
}

@MainActor
enum LaunchScenarioBootstrap {
    static func resolve(arguments: [String]) -> LaunchScenarioResolution {
        do {
            let scenario = try LaunchScenarioParser.parse(arguments: arguments)
            let displayProfile = try LaunchDisplayProfileParser.parse(
                arguments: arguments
            )
            return .ready(
                LaunchScenarioFactory.make(
                    scenario: scenario,
                    displayProfile: displayProfile
                )
            )
        } catch {
            return .invalid(code: "invalid-scenario")
        }
    }
}

#if UITESTING
@MainActor
struct LaunchScenarioFailureView: View {
    let code: String

    var body: some View {
        Text(code)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("app.launch-scenario.invalid")
    }
}

@MainActor
struct LaunchDisplayProfileModifier: ViewModifier {
    let profile: LaunchDisplayProfile

    @ViewBuilder
    func body(content: Content) -> some View {
        switch profile {
        case .system:
            content
        case .darkAccessibilityReduced:
            content
                .preferredColorScheme(.dark)
                .environment(\.dynamicTypeSize, .accessibility3)
                .environment(\.motionReductionOverride, true)
        case .darkAccessibilityMaximumReduced:
            content
                .preferredColorScheme(.dark)
                .environment(\.dynamicTypeSize, .accessibility5)
                .environment(\.motionReductionOverride, true)
        }
    }
}

@MainActor
struct LaunchShellLayoutHarness<Content: View>: View {
    @Environment(\.horizontalSizeClass)
    private var inheritedHorizontalSizeClass
    @State private var sizeClassOverride: UserInterfaceSizeClass?

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.small) {
                Button("测试紧凑布局") {
                    sizeClassOverride = .compact
                }
                .accessibilityIdentifier("app.harness.layout.compact")

                Button("测试常规布局") {
                    sizeClassOverride = .regular
                }
                .accessibilityIdentifier("app.harness.layout.regular")
            }
            .font(Typography.font(.caption))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xSmall)
            .background(SemanticColor.surface)

            layoutContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var layoutContent: some View {
        content.environment(
            \.horizontalSizeClass,
            sizeClassOverride ?? inheritedHorizontalSizeClass
        )
    }
}
#endif
#endif
