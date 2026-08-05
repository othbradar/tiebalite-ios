import SwiftUI

struct ContentSummaryCard<Supplementary: View>: View {
    let title: String
    let primaryMetadata: String
    let primarySystemImage: String
    let secondaryMetadata: String
    let secondarySystemImage: String
    let trailingMetadata: String
    let trailingAccessibilityLabel: String
    private let supplementary: Supplementary

    init(
        title: String,
        primaryMetadata: String,
        primarySystemImage: String,
        secondaryMetadata: String,
        secondarySystemImage: String,
        trailingMetadata: String,
        trailingAccessibilityLabel: String,
        @ViewBuilder supplementary: () -> Supplementary
    ) {
        self.title = title
        self.primaryMetadata = primaryMetadata
        self.primarySystemImage = primarySystemImage
        self.secondaryMetadata = secondaryMetadata
        self.secondarySystemImage = secondarySystemImage
        self.trailingMetadata = trailingMetadata
        self.trailingAccessibilityLabel = trailingAccessibilityLabel
        self.supplementary = supplementary()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .font(Typography.font(.headline))
                .foregroundStyle(SemanticColor.primaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            supplementary

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.small) {
                    metadata(primaryMetadata, systemImage: primarySystemImage)
                    metadata(secondaryMetadata, systemImage: secondarySystemImage)
                    Spacer(minLength: Spacing.xSmall)
                    trailingLabel
                }

                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    metadata(primaryMetadata, systemImage: primarySystemImage)
                    metadata(secondaryMetadata, systemImage: secondarySystemImage)
                    trailingLabel
                }
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func metadata(
        _ value: String,
        systemImage: String
    ) -> some View {
        Label(value, systemImage: systemImage)
            .font(Typography.font(.caption))
            .foregroundStyle(SemanticColor.secondaryText)
            .lineLimit(2)
    }

    private var trailingLabel: some View {
        Label(trailingMetadata, systemImage: "bubble.left")
            .font(Typography.font(.caption))
            .foregroundStyle(SemanticColor.secondaryText)
            .accessibilityLabel(trailingAccessibilityLabel)
    }
}

extension ContentSummaryCard where Supplementary == EmptyView {
    init(
        title: String,
        primaryMetadata: String,
        primarySystemImage: String,
        secondaryMetadata: String,
        secondarySystemImage: String,
        trailingMetadata: String,
        trailingAccessibilityLabel: String
    ) {
        self.init(
            title: title,
            primaryMetadata: primaryMetadata,
            primarySystemImage: primarySystemImage,
            secondaryMetadata: secondaryMetadata,
            secondarySystemImage: secondarySystemImage,
            trailingMetadata: trailingMetadata,
            trailingAccessibilityLabel: trailingAccessibilityLabel
        ) {
            EmptyView()
        }
    }
}
