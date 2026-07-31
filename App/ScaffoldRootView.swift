import SwiftUI
import UIKit

@MainActor
struct ScaffoldRootView: View {
    private let buildConfiguration: ScaffoldEnvironment.BuildConfiguration
    private let harnessLabel: String?

    init(
        buildConfiguration: ScaffoldEnvironment.BuildConfiguration =
            ScaffoldEnvironment.currentBuildConfiguration,
        harnessLabel: String? = nil
    ) {
        self.buildConfiguration = buildConfiguration
        self.harnessLabel = harnessLabel
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

            if let harnessLabel {
                Text(harnessLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("app.launch-placeholder.scenario")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(uiColor: .systemBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app.launch-placeholder.root")
    }
}
