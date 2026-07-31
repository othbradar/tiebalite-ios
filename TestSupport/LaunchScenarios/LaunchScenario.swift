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
    case networkOffline = "network.offline"
    case networkSlow = "network.slow"
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
            return .ready(LaunchScenarioFactory.make(scenario: scenario))
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
#endif
#endif
