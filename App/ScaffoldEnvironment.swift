struct ScaffoldEnvironment: Sendable {
    enum BuildConfiguration: Equatable, Sendable {
        case debug
        case release
        case uiTesting

        var displayName: String {
            switch self {
            case .debug:
                "Debug"
            case .release:
                "Release"
            case .uiTesting:
                "UITesting"
            }
        }
    }

    static let appName = "TiebaLite"
    static let statusText = "Design system and app shell"
    static let platformText = "iOS & iPadOS 18+"

    static var currentBuildConfiguration: BuildConfiguration {
#if UITESTING
        .uiTesting
#elseif DEBUG
        .debug
#else
        .release
#endif
    }
}
