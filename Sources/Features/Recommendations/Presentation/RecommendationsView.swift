import SwiftUI

@MainActor
struct RecommendationsView: View {
    @Bindable var store: RecommendationsStore
    let imageLoader: any ImageLoading
    let onOpenThread: (RecommendationSummary) -> Void

    var onOpenUser: (UserProfileRoute) -> Void = { _ in }

    @Environment(\.openURL) private var openURL

    @State private var retryGeneration: UInt64 = 0

    var body: some View {
        content
        .background(SemanticColor.background)
        .navigationTitle("动态")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("动态")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(RecommendationsAccessibilityID.root)
            }
        }
        .task(id: retryGeneration) {
            await loadStoreAcrossProjection()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .initialLoading:
            VStack(spacing: 0) {
                ForEach(0..<3) { _ in
                    TiebaFeedRowSkeleton().padding(.horizontal, TiebaParityTokens.horizontalInset)
                    TiebaFlatDivider()
                }
                Spacer(minLength: 0)
            }
            .accessibilityIdentifier(RecommendationsAccessibilityID.initialLoading)
        case let .loaded(items),
             let .loadingNextPage(items),
             let .nextPageFailure(items),
             let .refreshing(items),
             let .refreshFailure(items):
            recommendationList(items)
        case .empty:
            EmptyStateView(
                title: "暂无推荐",
                message: "当前没有可显示的帖子。",
                systemImage: "rectangle.stack"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SemanticColor.background)
            .accessibilityIdentifier(RecommendationsAccessibilityID.empty)
        case .initialFailure:
            FullPageErrorView(
                title: "推荐加载失败",
                message: "推荐服务暂时不可用。",
                retry: requestRetry
            )
            .accessibilityIdentifier(RecommendationsAccessibilityID.failure)
        }
    }

    private func recommendationList(
        _ items: [RecommendationSummary]
    ) -> some View {
        let presentation = RecommendationsListPresentation(items: items, pagination: paginationFooterState)
        return VirtualizedList(
            items: presentation.rows,
            backgroundColor: .systemBackground,
            accessibilityIdentifier: RecommendationsAccessibilityID.list,
            // The shared coordinator consumes this only when creating a new table.
            // Updates, image completions and Tab returns keep the live table offset.
            restoredAnchor: presentation.restoredRowID(for: store.scrollAnchor),
            onPrefetch: { rowIDs in
                guard let threadID = presentation.prefetchThreadID(in: rowIDs) else { return }
                store.requestNextPage(after: threadID)
            },
            onScrollSettled: { rowID in
                guard let threadID = presentation.threadAnchor(for: rowID) else { return }
                store.setScrollAnchor(threadID)
            },
            rowContent: { row in
                recommendationListRow(row)
            }
        )
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func recommendationListRow(_ row: RecommendationsRowModel) -> some View {
        switch row.content {
        case let .thread(item):
            RecommendationFeedRow(item: item, imageLoader: imageLoader, openURL: openURL, onOpenUser: onOpenUser) {
                onOpenThread(item)
            }
            .id(item.threadID)
        case let .pagination(state):
            PaginationFooter(state: state, retry: requestNextPage)
        }
    }

    private func requestRetry() {
        store.prepareRetry()
        retryGeneration &+= 1
    }

    private func requestNextPage() {
        Task { @MainActor in
            await store.loadNextPage()
        }
    }

    private func loadStoreAcrossProjection() async {
        let operation = Task { @MainActor in
            await store.loadIfNeeded()
        }
        await operation.value
    }

    private var paginationFooterState: PaginationFooterState {
        switch store.state {
        case .loadingNextPage:
            .loading
        case .nextPageFailure:
            .failure
        case .loaded, .refreshing, .refreshFailure:
            store.nextPage == nil ? .end : .idle
        case .empty, .initialFailure, .initialLoading:
            .idle
        }
    }
}

enum RecommendationsAccessibilityID {
    static let empty = "recommendations.state.empty"
    static let failure = "recommendations.state.failure"
    static let initialLoading = "recommendations.state.initial-loading"
    static let list = "recommendations.list"
    static let root = "app.root.recommendations"
    static let sessionExpired = "recommendations.session.expired"
    static let sessionLogin = "recommendations.session.login"
    static let sessionSignedOut = "recommendations.session.signed-out"
    static let sessionSigningIn = "recommendations.session.signing-in"
    static let shellTitle = "app.shell.title"

    static func row(_ threadID: Int64) -> String {
        "recommendations.row.t\(threadID)"
    }

    static func thumbnail(_ threadID: Int64) -> String {
        "recommendations.thumbnail.t\(threadID)"
    }
}
