import SwiftUI
import UIKit

enum SearchAccessibilityID {
    static let empty = "search.empty"
    static let failure = "search.failure"
    static let field = "search.field"
    static let list = "search.list"
    static let loading = "search.loading"
    static let root = "search.root"
    static let submit = "search.submit"

    static func forum(_ forumID: Int64) -> String {
        "search.forum.\(forumID)"
    }

    static func thread(_ threadID: Int64) -> String {
        "search.thread.\(threadID)"
    }
}

@MainActor
struct SearchView: View {
    @Bindable var store: SearchStore
    @FocusState private var isSearchFieldFocused: Bool
    let onOpenForum: (ForumSearchResult) -> Void
    let onOpenThread: (ThreadSearchResult) -> Void

    var body: some View {
        VStack(spacing: 0) {
            searchForm
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle("搜索")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SearchAccessibilityID.root)
        .onDisappear {
            store.cancel()
        }
    }

    private var searchForm: some View {
        HStack(spacing: Spacing.small) {
            TextField(
                "搜索贴吧和帖子",
                text: Binding(
                    get: { store.draftKeyword },
                    set: { value in
                        store.setDraftKeyword(value)
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            .focused($isSearchFieldFocused)
            .submitLabel(.search)
            .onSubmit(requestSubmit)
            .accessibilityIdentifier(SearchAccessibilityID.field)

            Button("搜索", action: requestSubmit)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(SearchAccessibilityID.submit)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(SemanticColor.surface)
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle:
            EmptyStateView(
                title: "搜索贴吧和帖子",
                message: "输入关键词后点击搜索。",
                systemImage: "magnifyingglass"
            )
        case .searching:
            InitialLoadingView(title: "正在搜索")
                .accessibilityIdentifier(SearchAccessibilityID.loading)
        case .empty:
            EmptyStateView(
                title: "没有找到结果",
                message: "可以换一个关键词再试。",
                systemImage: "magnifyingglass"
            )
            .accessibilityIdentifier(SearchAccessibilityID.empty)
        case .failed(_, _, nil):
            FullPageErrorView(
                title: "搜索失败",
                message: "网络或服务暂时不可用。",
                retry: requestRetry
            )
            .accessibilityIdentifier(SearchAccessibilityID.failure)
        case .failed, .loaded, .loadingMore:
            resultsList
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if let presentation = store.listPresentation {
            VirtualizedList(
                items: presentation.rows,
                backgroundColor: .systemBackground,
                accessibilityIdentifier: SearchAccessibilityID.list,
                restoredAnchor: store.scrollAnchor,
                onPrefetch: { rowIDs in
                    guard rowIDs.contains(where: {
                        presentation.prefetchRowIDs.contains($0)
                    }) else {
                        return
                    }
                    requestNextPage()
                },
                onScrollSettled: store.setScrollAnchor,
                rowContent: { row in
                    SearchRowView(
                        row: row,
                        onOpenForum: onOpenForum,
                        onOpenThread: onOpenThread,
                        retryNextPage: requestNextPage
                    )
                }
            )
            .background(SemanticColor.background)
            .accessibilityElement(children: .contain)
        } else {
            InitialLoadingView(title: "正在搜索")
        }
    }

    private func requestSubmit() {
        isSearchFieldFocused = false
        Task { @MainActor in
            await store.submit()
        }
    }

    private func requestRetry() {
        Task { @MainActor in
            await store.retry()
        }
    }

    private func requestNextPage() {
        Task { @MainActor in
            await store.loadNextPage()
        }
    }
}

@MainActor
private struct SearchRowView: View {
    let row: SearchRowModel
    let onOpenForum: (ForumSearchResult) -> Void
    let onOpenThread: (ThreadSearchResult) -> Void
    let retryNextPage: () -> Void

    @ViewBuilder
    var body: some View {
        switch row.content {
        case let .section(section):
            Text(section.title)
                .font(Typography.font(.headline))
                .foregroundStyle(SemanticColor.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.medium)
                .padding(.top, Spacing.medium)
                .accessibilityAddTraits(.isHeader)
        case let .empty(section):
            Text(section.emptyMessage)
                .font(Typography.font(.body))
                .foregroundStyle(SemanticColor.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
        case let .forum(row):
            Button {
                onOpenForum(row.result)
            } label: {
                ForumSearchResultCard(row: row)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .accessibilityHint("打开吧首页")
            .accessibilityIdentifier(
                SearchAccessibilityID.forum(row.result.forumID)
            )
        case let .thread(row):
            Button {
                onOpenThread(row.result)
            } label: {
                ContentSummaryCard(
                    title: row.title,
                    primaryMetadata: row.forumName,
                    primarySystemImage: "rectangle.stack",
                    secondaryMetadata: row.authorName,
                    secondarySystemImage: "person",
                    trailingMetadata: row.replyText,
                    trailingAccessibilityLabel: "\(row.replyText) 条回复"
                ) {
                    if let summary = row.summary {
                        Text(summary)
                            .font(Typography.font(.body))
                            .foregroundStyle(SemanticColor.secondaryText)
                            .multilineTextAlignment(.leading)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .accessibilityHint("打开只读帖子")
            .accessibilityIdentifier(
                SearchAccessibilityID.thread(row.result.threadID)
            )
        case let .pagination(state):
            PaginationFooter(state: state, retry: retryNextPage)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
        }
    }
}

@MainActor
private struct ForumSearchResultCard: View {
    let row: ForumSearchRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Label(row.title, systemImage: "rectangle.stack.fill")
                .font(Typography.font(.headline))
                .foregroundStyle(SemanticColor.primaryText)

            if let summary = row.summary {
                Text(summary)
                    .font(Typography.font(.body))
                    .foregroundStyle(SemanticColor.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            if let statistics = row.statistics {
                Text(statistics)
                    .font(Typography.font(.caption))
                    .foregroundStyle(SemanticColor.secondaryText)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private extension SearchResultSection {
    var title: String {
        switch self {
        case .forums:
            "贴吧"
        case .threads:
            "帖子"
        }
    }

    var emptyMessage: String {
        switch self {
        case .forums:
            "没有匹配的贴吧。"
        case .threads:
            "没有匹配的帖子。"
        }
    }
}
