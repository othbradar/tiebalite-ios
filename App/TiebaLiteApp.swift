import Foundation
import SwiftUI

@main
@MainActor
struct TiebaLiteApp: App {
#if UITESTING
    private let launchResolution: LaunchScenarioResolution

    init() {
        launchResolution = LaunchScenarioBootstrap.resolve(
            arguments: ProcessInfo.processInfo.arguments
        )
    }
#else
    private let compositionRoot = AppCompositionRoot.production()
#endif

    var body: some Scene {
        WindowGroup {
#if UITESTING
            switch launchResolution {
            case let .ready(descriptor):
                ScaffoldRootView(harnessLabel: descriptor.safeLabel)
            case let .invalid(code):
                LaunchScenarioFailureView(code: code)
            }
#else
            ScaffoldRootView()
#endif
        }
    }
}
