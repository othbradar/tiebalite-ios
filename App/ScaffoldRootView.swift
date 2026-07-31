import SwiftUI
import UIKit

@MainActor
struct ScaffoldRootView: View {
    private let buildConfiguration: ScaffoldEnvironment.BuildConfiguration

    init(
        buildConfiguration: ScaffoldEnvironment.BuildConfiguration =
            ScaffoldEnvironment.currentBuildConfiguration
    ) {
        self.buildConfiguration = buildConfiguration
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(ScaffoldEnvironment.appName)
                .font(.title.bold())
                .accessibilityIdentifier("app.launch-placeholder.title")

            Text(ScaffoldEnvironment.statusText)
                .font(.headline)

            Text(
                "\(buildConfiguration.displayName) · \(ScaffoldEnvironment.platformText)"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("app.launch-placeholder.environment")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(uiColor: .systemBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app.launch-placeholder.root")
    }
}
