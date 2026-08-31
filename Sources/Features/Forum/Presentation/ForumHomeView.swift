import SwiftUI
import UIKit

@MainActor
struct ForumHomeView: View {
    @Bindable var store: ForumHomeStore
    let route: ForumRoute
    let onOpenThread: (ForumThreadSummary) -> Void
    let onDisplayed: (ForumSummary) async -> Void

    init(
        store: ForumHomeStore,
        route: ForumRoute,
        onOpenThread: @escaping (ForumThreadSummary) -> Void,
        onDisplayed: @escaping (ForumSummary) async -> Void = { _ in }
    ) {
        self.store = store
        self.route = route
        self.onOpenThread = onOpenThread
        self.onDisplayed = onDisplayed
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle(route.forumName.rawValue)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppAccessibilityID.routeForum)
        .task(id: route) {
            await synchronizeStoreAcrossProjection()
        }
        .task(id: displayedForumID) {
            await recordDisplayedForumAcrossProjection()
        }
        .toolbar {
            if store.state.canReload {
                Button("重新加载", systemImage: "arrow.clockwise") {
                    requestReload()
                }
                .accessibilityIdentifier(ForumHomeAccessibilityID.reload)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .initialLoading:
            InitialLoadingView(title: "正在加载吧首页")
                .accessibilityIdentifier(
                    ForumHomeAccessibilityID.initialLoading
                )
        case .initialFailure:
            FullPageErrorView(
                title: "吧首页加载失败",
                message: "网络或服务暂时不可用。",
                retry: requestReload
            )
            .accessibilityIdentifier(ForumHomeAccessibilityID.failure)
        case .empty,
             .loaded,
             .loadingNextPage,
             .nextPageFailure,
             .refreshFailure,
             .refreshing:
            forumList
        }
    }

    @ViewBuilder
    private var forumList: some View {
        if let presentation = store.listPresentation {
            VirtualizedList(
                items: presentation.rows,
                backgroundColor: .systemBackground,
                accessibilityIdentifier: ForumHomeAccessibilityID.list,
                restoredAnchor: store.scrollAnchor.map(ForumHomeRowID.thread),
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
                    ForumHomeRowView(
                        row: row,
                        onOpenThread: onOpenThread,
                        requestReload: requestReload,
                        requestNextPage: requestNextPage
                    )
                }
            )
            .background(SemanticColor.background)
            .accessibilityElement(children: .contain)
        } else {
            InitialLoadingView(title: "正在加载吧首页")
        }
    }

    private func requestReload() {
        Task { @MainActor in
            await store.reload()
        }
    }

    private func requestNextPage() {
        Task { @MainActor in
            await store.loadNextPage()
        }
    }

    private func synchronizeStoreAcrossProjection() async {
        let operation = Task { @MainActor in
            await store.synchronize(with: route)
        }
        await operation.value
    }

    private func recordDisplayedForumAcrossProjection() async {
        let operation = Task { @MainActor in
            guard let forum = store.state.displayedForum,
                  let forumID = forum.forumID,
                  store.claimDisplayedForum(forumID) else {
                return
            }
            await onDisplayed(forum)
        }
        await operation.value
    }

    private var displayedForumID: Int64? {
        store.state.displayedForum?.forumID
    }
}

@MainActor
struct ForumHomeRowView: View {
    let row: ForumHomeRowModel
    let onOpenThread: (ForumThreadSummary) -> Void
    let requestReload: () -> Void
    let requestNextPage: () -> Void

    @ViewBuilder
    var body: some View {
        switch row.content {
        case let .header(forum):
            ForumHeaderView(forum: forum)
                .padding(.horizontal, Spacing.medium)
                .padding(.top, Spacing.medium)
                .padding(.bottom, Spacing.small)
        case let .retainedStatus(status):
            retainedStatus(status)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
        case let .section(section):
            Text(section.title)
                .font(Typography.font(.headline))
                .foregroundStyle(SemanticColor.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.medium)
                .padding(.top, Spacing.medium)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(section.accessibilityIdentifier)
        case let .thread(thread):
            Button {
                onOpenThread(thread.sourceSummary)
            } label: {
                ForumThreadCard(row: thread)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .accessibilityHint("打开只读帖子")
            .accessibilityIdentifier(
                ForumHomeAccessibilityID.row(thread.threadID)
            )
        case .empty:
            EmptyStateView(
                title: "暂无帖子",
                message: "这个吧当前没有可显示的帖子。",
                systemImage: "rectangle.stack"
            )
            .frame(maxWidth: .infinity, minHeight: 320)
            .accessibilityIdentifier(ForumHomeAccessibilityID.empty)
        case let .pagination(pagination):
            PaginationFooter(
                state: pagination.footerState,
                retry: requestNextPage
            )
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
        }
    }

    @ViewBuilder
    private func retainedStatus(_ status: ForumHomeRetainedStatus) -> some View {
        switch status {
        case .refreshing:
            InlineLoadingView(title: "正在重新加载")
        case .refreshFailure:
            InlineErrorView(
                message: "重新加载失败，已保留原列表。",
                retry: requestReload
            )
        }
    }
}

@MainActor
private struct ForumThreadCard: View {
    let row: ForumThreadRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if row.rowKind == .top {
                Label("置顶", systemImage: "pin.fill")
                    .font(Typography.font(.caption))
                    .foregroundStyle(SemanticColor.accent)
            }

            Text(row.title)
                .font(Typography.font(.headline))
                .foregroundStyle(SemanticColor.primaryText)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let summary = row.summary {
                Text(summary)
                    .font(Typography.font(.body))
                    .foregroundStyle(SemanticColor.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            mediaPreview

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.small) {
                    metadata(row.forumName, systemImage: "rectangle.stack")
                    metadata(row.authorName, systemImage: "person")
                    Spacer(minLength: Spacing.xSmall)
                    metadata(
                        "\(row.replyCount)",
                        systemImage: "bubble.left",
                        accessibilityLabel: "\(row.replyCount) 条回复"
                    )
                }
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    metadata(row.forumName, systemImage: "rectangle.stack")
                    metadata(row.authorName, systemImage: "person")
                    metadata(
                        "\(row.replyCount) 条回复",
                        systemImage: "bubble.left"
                    )
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

    @ViewBuilder
    private var mediaPreview: some View {
        if !row.thumbnailDescriptions.isEmpty {
            HStack(spacing: Spacing.xSmall) {
                ForEach(row.thumbnailDescriptions) { thumbnail in
                    ZStack {
                        SemanticColor.background
                        Image(systemName: "photo")
                            .foregroundStyle(SemanticColor.secondaryText)
                            .accessibilityHidden(true)
                        if thumbnail.id == row.thumbnailDescriptions.last?.id,
                           row.additionalThumbnailCount > 0 {
                            Text("+\(row.additionalThumbnailCount)")
                                .font(Typography.font(.caption))
                                .foregroundStyle(SemanticColor.primaryText)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                    )
                    .accessibilityLabel(thumbnail.alternativeText)
                    .accessibilityValue("占位图")
                }
            }
        } else if row.rowKind == .video {
            Label("视频内容", systemImage: "play.rectangle.fill")
                .font(Typography.font(.subheadline))
                .foregroundStyle(SemanticColor.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(SemanticColor.background)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
    }

    private func metadata(
        _ value: String,
        systemImage: String,
        accessibilityLabel: String? = nil
    ) -> some View {
        Label(value, systemImage: systemImage)
            .font(Typography.font(.caption))
            .foregroundStyle(SemanticColor.secondaryText)
            .lineLimit(2)
            .accessibilityLabel(accessibilityLabel ?? value)
    }
}

@MainActor
private struct ForumHeaderView: View {
    let forum: ForumSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Label("\(forum.name)吧", systemImage: "rectangle.stack.fill")
                .font(Typography.font(.title))
                .foregroundStyle(SemanticColor.primaryText)

            if let slogan = forum.slogan {
                Text(slogan)
                    .font(Typography.font(.body))
                    .foregroundStyle(SemanticColor.secondaryText)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.medium) {
                    statistic("关注", value: forum.memberCount)
                    statistic("主题", value: forum.threadCount)
                    statistic("帖子", value: forum.postCount)
                }
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    statistic("关注", value: forum.memberCount)
                    statistic("主题", value: forum.threadCount)
                    statistic("帖子", value: forum.postCount)
                }
            }
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(ForumHomeAccessibilityID.header)
    }

    private func statistic(_ label: String, value: Int) -> some View {
        Text("\(label) \(value)")
            .font(Typography.font(.caption))
            .foregroundStyle(SemanticColor.secondaryText)
    }
}

private extension ForumHomeState {
    var canReload: Bool {
        switch self {
        case .empty,
             .initialFailure,
             .loaded,
             .nextPageFailure,
             .refreshFailure:
            true
        case .initialLoading, .loadingNextPage, .refreshing:
            false
        }
    }
}

private extension ForumHomeSection {
    var title: String {
        switch self {
        case .pinned:
            "置顶帖"
        case .regular:
            "全部帖子"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .pinned:
            ForumHomeAccessibilityID.pinnedSection
        case .regular:
            ForumHomeAccessibilityID.regularSection
        }
    }
}

private extension ForumHomePaginationPresentation {
    var footerState: PaginationFooterState {
        switch self {
        case .idle:
            .idle
        case .loading:
            .loading
        case .failure:
            .failure
        case .end:
            .end
        }
    }
}

enum ForumHomeAccessibilityID {
    static let empty = "forum-home.state.empty"
    static let failure = "forum-home.state.failure"
    static let header = "forum-home.header"
    static let initialLoading = "forum-home.state.initial-loading"
    static let list = "forum-home.list"
    static let pinnedSection = "forum-home.section.pinned"
    static let regularSection = "forum-home.section.regular"
    static let reload = "forum-home.reload"

    static func row(_ threadID: Int64) -> String {
        "forum-home.row.t\(threadID)"
    }
}
