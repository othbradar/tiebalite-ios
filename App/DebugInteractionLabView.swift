#if DEBUG
import SwiftUI

@MainActor
struct DebugInteractionLabView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case media
        case pager

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .pager:
                "Pager"
            case .media:
                "Media"
            }
        }
    }

    private static let isolationCanary = "TIEBALITE_INTERACTION_LAB_CANARY"

    @State private var section = Section.pager

    var body: some View {
        VStack(spacing: Spacing.small) {
            Text(Self.isolationCanary)
                .frame(width: 0, height: 0)
                .hidden()
                .accessibilityHidden(true)

            Text("Interaction Lab")
                .font(Typography.font(.headline))
                .accessibilityIdentifier("interaction.lab.title")

            Picker("实验区域", selection: $section) {
                ForEach(Section.allCases) { section in
                    Text(section.title)
                        .accessibilityIdentifier(
                            "interaction.lab.section.\(section.rawValue)"
                        )
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("interaction.lab.section")

            switch section {
            case .pager:
                DebugPagerLabView()
            case .media:
                DebugMediaLabView()
            }
        }
        .padding(.horizontal, Spacing.small)
        .background(SemanticColor.background)
        .navigationTitle("交互实验室")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
