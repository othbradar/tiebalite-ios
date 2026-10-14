import SwiftUI

struct ExploreFeedView: View {
    @Bindable var store: ExploreFeedStore
    let imageLoader: any ImageLoading
    let openLogin: () -> Void
    let openThread: (RecommendationSummary) -> Void
    let openUser: (UserProfileRoute) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if let presentation = store.presentation {
                VirtualizedList(
                    items: presentation.rows, backgroundColor: .systemBackground,
                    accessibilityIdentifier: "explore.\(store.feed.rawValue).list",
                    restoredAnchor: store.anchor.map(RecommendationsRowID.thread),
                    onPrefetch: store.prefetchRows, onScrollSettled: store.setAnchor,
                    onRefresh: { await store.refresh() }, pendingRefresh: store.pendingRefreshCommit,
                    rowContent: row)
            } else {
                status
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("explore.\(store.feed.rawValue).page")
    }

    @ViewBuilder private var status: some View {
        switch store.state {
        case .loginRequired:
            VStack(spacing: Spacing.medium) {
                Text("登录后查看关注动态").font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                Button("登录", action: openLogin).accessibilityIdentifier("explore.following.login")
            }
        case .failed:
            FullPageErrorView(title: "\(store.feed.title)加载失败", message: "网络或服务暂时不可用。") {
                Task { await store.refresh() }
            }
            .accessibilityIdentifier("explore.\(store.feed.rawValue).failed")
        case .empty:
            VStack(spacing: Spacing.medium) {
                Text("暂无\(store.feed.title)内容").font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                Button(store.next == nil ? "重新加载" : "加载更多") {
                    Task { if store.next == nil { await store.refresh() } else { await store.loadMore() } }
                }.accessibilityIdentifier("explore.\(store.feed.rawValue).empty.retry")
            }
        case .idle:
            SemanticColor.background
        default:
            InitialLoadingView(title: "正在加载\(store.feed.title)")
        }
    }

    @ViewBuilder private func row(_ model: RecommendationsRowModel) -> some View {
        switch model.content {
        case let .thread(item):
            RecommendationFeedRow(item: item, imageLoader: imageLoader, openURL: openURL,
                                  onOpenUser: openUser, openThread: { openThread(item) })
        case let .pagination(state):
            if store.state == .refreshFailure {
                Button("刷新失败，点此重试") { Task { await store.refresh() } }
                    .font(.caption).foregroundStyle(SemanticColor.secondaryText).frame(minHeight: 44)
                    .accessibilityIdentifier("explore.\(store.feed.rawValue).refresh-retry")
            } else {
                PaginationFooter(state: state, retry: { Task { await store.loadMore() } })
            }
        }
    }
}
