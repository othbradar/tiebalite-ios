import SwiftUI

@MainActor
struct SubpostsView: View {
    @Bindable var store: SubpostsStore
    let imageLoader: any ImageLoading
    let readingTextSize: ReadingTextSizePreference
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let onOpenUser: (UserProfileRoute) -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var composeTarget: TextComposeTarget?
    @State private var actionTask: Task<Void, Never>?

    var body: some View {
        Group {
            if store.snapshot != nil {
                VirtualizedList(
                    items: store.rows, backgroundColor: .systemBackground,
                    accessibilityIdentifier: "subposts.list", restoredAnchor: store.readAnchor,
                    onPrefetch: { ids in
                        guard actionTask == nil else { return }
                        actionTask = Task {
                            await store.prefetch(ids)
                            actionTask = nil
                        }
                    },
                    onScrollSettled: store.setReadAnchor,
                    onRefresh: { await store.refresh() },
                    rowContent: { row in
                        rowContent(row)
                    })
            } else if store.phase == .initialFailure {
                FullPageErrorView(title: "回复加载失败", message: "请稍后重试。", retry: refresh)
                    .accessibilityIdentifier("subposts.failure")
            } else {
                InitialLoadingView(title: "正在加载回复")
            }
        }
        .background(SemanticColor.background)
        .navigationTitle(store.snapshot?.parent.map { "\($0.floorNumber) 楼的回复" } ?? "回复")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26.0, *) {
                refreshToolbarItem.sharedBackgroundVisibility(.hidden)
            } else {
                refreshToolbarItem
            }
        }
        .textComposer(target: $composeTarget) { _ in await store.refresh() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app.route.subposts")
        .accessibilityValue("帖子 \(store.route.threadID.formatted())，楼层 \(store.route.postID.formatted())")
        .onDisappear { Task { await store.saveReadingPosition() } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await store.saveReadingPosition() } }
        }
        .task(id: store.cacheContext) { await store.loadIfNeeded() }
    }

    private var refreshToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("刷新", systemImage: "arrow.clockwise", action: refresh)
                .accessibilityIdentifier("subposts.refresh")
        }
    }

    @ViewBuilder
    private func rowContent(_ row: SubpostsRow) -> some View {
        switch row.content {
        case .parent(let parent, let threadAuthorID):
            SubpostsContentRow(
                author: parent.author, metadata: parent.metadata, document: parent.document,
                isThreadAuthor: parent.author.isThreadAuthor(threadAuthorID), imageLoader: imageLoader,
                readingTextSize: readingTextSize, onOpenMedia: onOpenMedia, onOpenUser: onOpenUser,
                identifier: "subposts.parent", reply: nil)
        case .count(let count):
            Text("\(count) 条回复").font(Typography.font(.subheadline)).fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 8)
                .accessibilityIdentifier("subposts.count")
        case .reply(let item, let isThreadAuthor):
            SubpostsContentRow(
                author: item.author, metadata: item.metadata, document: item.document,
                isThreadAuthor: isThreadAuthor, imageLoader: imageLoader, readingTextSize: readingTextSize,
                onOpenMedia: onOpenMedia, onOpenUser: onOpenUser, identifier: "subposts.reply.\(item.id)",
                reply: {
                    if let intent = store.replyIntent(for: item) { composeTarget = .reply(intent, document: item.document) }
                })
        case .footer(let phase, let hasMore):
            footer(phase, hasMore: hasMore)
        }
    }

    @ViewBuilder
    private func footer(_ phase: SubpostsPhase, hasMore: Bool) -> some View {
        if phase == .refreshFailure {
            Button("正在显示已缓存内容，刷新失败，重试", action: refresh).frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("subposts.refresh-retry")
        } else if phase == .loadingNextPage || phase == .refreshing {
            PaginationFooter(state: .loading, retry: {})
        } else if phase == .nextPageFailure || hasMore {
            Button(phase == .nextPageFailure ? "已保留内容，加载失败，重试" : (store.isShowingCachedContent ? "已缓存内容 · 加载更多" : "加载更多")) {
                guard actionTask == nil else { return }
                actionTask = Task {
                    await store.loadNextPage()
                    actionTask = nil
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("subposts.more")
        } else {
            Text(store.snapshot?.items.isEmpty == true ? "暂无回复" : (store.isShowingCachedContent ? "已缓存内容 · 已经到底了" : "已经到底了"))
                .font(Typography.font(.caption)).foregroundStyle(SemanticColor.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("subposts.end")
        }
    }

    private func refresh() {
        actionTask?.cancel()
        actionTask = Task {
            await store.refresh()
            actionTask = nil
        }
    }
}
