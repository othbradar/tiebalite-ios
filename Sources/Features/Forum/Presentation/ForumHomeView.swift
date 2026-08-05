import SwiftUI

@MainActor
struct ForumHomeView: View {
    @Bindable var store: ForumHomeStore
    let route: ForumRoute
    let onOpenThread: (ForumThreadSummary) -> Void

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
                await store.synchronize(with: route)
            }
            .onDisappear {
                store.cancel()
            }
            .toolbar {
                if store.state.canReload {
                    Button("重新加载", systemImage: "arrow.clockwise") {
                        Task {
                            await store.reload()
                        }
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
        case let .empty(forum):
            forumList(
                ForumHomeSnapshot(forum: forum, threads: []),
                empty: true
            )
        case let .loaded(snapshot):
            forumList(snapshot)
        case let .refreshing(snapshot):
            forumList(snapshot, status: .loading)
        case let .refreshFailure(snapshot, _):
            forumList(snapshot, status: .failure)
        }
    }

    private func forumList(
        _ snapshot: ForumHomeSnapshot,
        status: RetainedForumStatus? = nil,
        empty: Bool = false
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.medium) {
                ForumHeaderView(forum: snapshot.forum)

                if status == .loading {
                    InlineLoadingView(title: "正在重新加载")
                } else if status == .failure {
                    InlineErrorView(
                        message: "重新加载失败，已保留原列表。",
                        retry: requestReload
                    )
                }

                if empty {
                    EmptyStateView(
                        title: "暂无帖子",
                        message: "这个吧当前没有可显示的帖子。",
                        systemImage: "rectangle.stack"
                    )
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(ForumHomeAccessibilityID.empty)
                } else {
                    threadSection(
                        title: "置顶帖",
                        threads: snapshot.pinnedThreads,
                        identifier: ForumHomeAccessibilityID.pinnedSection
                    )
                    threadSection(
                        title: "全部帖子",
                        threads: snapshot.regularThreads,
                        identifier: ForumHomeAccessibilityID.regularSection
                    )
                }
            }
            .scrollTargetLayout()
            .padding(Spacing.medium)
        }
        .scrollPosition(id: scrollAnchorBinding, anchor: .center)
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ForumHomeAccessibilityID.list)
    }

    @ViewBuilder
    private func threadSection(
        title: String,
        threads: [ForumThreadSummary],
        identifier: String
    ) -> some View {
        if !threads.isEmpty {
            Text(title)
                .font(Typography.font(.headline))
                .foregroundStyle(SemanticColor.primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)

            ForEach(threads) { thread in
                Button {
                    onOpenThread(thread)
                } label: {
                    ContentSummaryCard(
                        title: thread.title,
                        primaryMetadata: thread.forumName,
                        primarySystemImage: "rectangle.stack",
                        secondaryMetadata: thread.authorName,
                        secondarySystemImage: "person",
                        trailingMetadata: "\(thread.replyCount)",
                        trailingAccessibilityLabel:
                            "\(thread.replyCount) 条回复"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("打开只读帖子")
                .accessibilityIdentifier(
                    ForumHomeAccessibilityID.row(thread.itemID)
                )
                .id(thread.itemID)
            }
        }
    }

    private var scrollAnchorBinding: Binding<Int64?> {
        Binding(
            get: { store.scrollAnchor },
            set: { store.setScrollAnchor($0) }
        )
    }

    private func requestReload() {
        Task {
            await store.reload()
        }
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

private enum RetainedForumStatus {
    case failure
    case loading
}

private extension ForumHomeState {
    var canReload: Bool {
        switch self {
        case .empty, .initialFailure, .loaded, .refreshFailure:
            true
        case .initialLoading, .refreshing:
            false
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

    static func row(_ itemID: Int64) -> String {
        "forum-home.row.i\(itemID)"
    }
}
