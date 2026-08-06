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
#if DEBUG && !UITESTING
    private let runsStage11LiveProbe = DebugLiveAPIProbeLaunch.isRequested(
        arguments: ProcessInfo.processInfo.arguments
    )
    private let runsStage14ForumProbe = DebugForumHomeProbeLaunch.isRequested(
        arguments: ProcessInfo.processInfo.arguments
    )
    private let runsStage15ThreadProbe = DebugStage15ThreadProbeLaunch
        .isRequested(arguments: ProcessInfo.processInfo.arguments)
    private let runsStage15LongThreadLab = DebugStage15LongThreadLabLaunch
        .isRequested(arguments: ProcessInfo.processInfo.arguments)
#endif
#endif

    var body: some Scene {
        WindowGroup {
#if UITESTING
            switch launchResolution {
            case let .ready(descriptor):
                LaunchShellLayoutHarness {
                    AppSceneRoot(
                        compositionRoot: descriptor.compositionRoot,
                        harnessLabel: descriptor.safeLabel
                    )
                    .modifier(
                        LaunchDisplayProfileModifier(
                            profile: descriptor.displayProfile
                        )
                    )
                }
            case let .invalid(code):
                LaunchScenarioFailureView(code: code)
            }
#else
#if DEBUG && !UITESTING
            if runsStage15LongThreadLab {
                DebugStage15LongThreadLabView()
            } else if runsStage15ThreadProbe {
                DebugStage15ThreadProbeView()
            } else if runsStage14ForumProbe {
                DebugForumHomeProbeView()
            } else if runsStage11LiveProbe {
                DebugLiveAPIProbeView()
            } else {
                AppSceneRoot(compositionRoot: compositionRoot)
            }
#else
            AppSceneRoot(compositionRoot: compositionRoot)
#endif
#endif
        }
    }
}
