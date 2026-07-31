import SwiftUI

@MainActor
struct InitialLoadingView: View {
    let title: String

    init(title: String = "正在加载") {
        self.title = title
    }

    var body: some View {
        VStack(spacing: Spacing.medium) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(Typography.font(.body))
                .foregroundStyle(SemanticColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.large)
        .background(SemanticColor.background)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("design-system.initial-loading")
    }
}

@MainActor
struct InlineLoadingView: View {
    let title: String

    init(title: String = "正在加载更多") {
        self.title = title
    }

    var body: some View {
        HStack(spacing: Spacing.small) {
            ProgressView()
            Text(title)
                .font(Typography.font(.subheadline))
                .foregroundStyle(SemanticColor.secondaryText)
        }
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("design-system.inline-loading")
    }
}

@MainActor
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: IconSize.large))
                .foregroundStyle(SemanticColor.secondaryText)
                .accessibilityHidden(true)
            Text(title)
                .font(Typography.font(.title))
                .foregroundStyle(SemanticColor.primaryText)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Typography.font(.body))
                .foregroundStyle(SemanticColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.large)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("design-system.empty-state")
    }
}

@MainActor
struct FullPageErrorView: View {
    let title: String
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: IconSize.large))
                .foregroundStyle(SemanticColor.error)
                .accessibilityHidden(true)
            Text(title)
                .font(Typography.font(.title))
                .foregroundStyle(SemanticColor.primaryText)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Typography.font(.body))
                .foregroundStyle(SemanticColor.secondaryText)
                .multilineTextAlignment(.center)
            Button("重试", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(SemanticColor.accent)
                .accessibilityIdentifier("design-system.full-page-error.retry")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.large)
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("design-system.full-page-error")
    }
}

@MainActor
struct InlineErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(SemanticColor.error)
                .accessibilityHidden(true)
            Text(message)
                .font(Typography.font(.subheadline))
                .foregroundStyle(SemanticColor.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("重试", action: retry)
                .accessibilityIdentifier("design-system.inline-error.retry")
        }
        .padding(Spacing.medium)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("design-system.inline-error")
    }
}

enum PaginationFooterState: Equatable, Sendable {
    case end
    case failure
    case idle
    case loading
}

@MainActor
struct PaginationFooter: View {
    let state: PaginationFooterState
    let retry: () -> Void

    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .loading:
                InlineLoadingView()
            case .failure:
                InlineErrorView(message: "加载更多失败", retry: retry)
            case .end:
                Text("已经到底了")
                    .font(Typography.font(.caption))
                    .foregroundStyle(SemanticColor.secondaryText)
                    .padding(.vertical, Spacing.small)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("design-system.pagination-footer")
    }
}
