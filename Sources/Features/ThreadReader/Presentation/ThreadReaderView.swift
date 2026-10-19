import SwiftUI
import UIKit

@MainActor
struct ThreadReaderView: View {
    @Bindable var store: ThreadReaderStore
    @Environment(\.threadReplyPreferences) private var replyPreferences
    var followsGlobalReplyPreferences = true
    @Environment(\.contentActions) private var contentActions
    let imageLoader: any ImageLoading
    let accountAvatar: ImageResourceDescriptor?
    let readingTextSize: ReadingTextSizePreference
    let readingEntry: ThreadReadingEntry
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let onOpenUser: (UserProfileRoute) -> Void
    let onDisplayed: (ThreadReaderSnapshot) async -> Void
    let onOpenSubposts: (ThreadContentSource) -> Void

    @Environment(\.bookmarks) private var bookmarks
    @Environment(\.favorites) private var favorites
    @Environment(\.scenePhase) private var scenePhase
    @State private var retryGeneration: UInt64 = 0
    @Environment(\.openURL) private var openURL
    @State private var composeTarget: TextComposeTarget?

    init(
        store: ThreadReaderStore,
        imageLoader: any ImageLoading,
        accountAvatar: ImageResourceDescriptor? = nil,
        readingTextSize: ReadingTextSizePreference = .standard,
        readingEntry: ThreadReadingEntry = .unspecified,
        followsGlobalReplyPreferences: Bool = true,
        onOpenMedia: @escaping (ThreadMediaIntent) -> Void,
        onOpenUser: @escaping (UserProfileRoute) -> Void = { _ in },
        onDisplayed: @escaping (ThreadReaderSnapshot) async -> Void = { _ in },
        onOpenSubposts: @escaping (ThreadContentSource) -> Void = { _ in }
    ) {
        self.store = store
        self.imageLoader = imageLoader
        self.accountAvatar = accountAvatar
        self.readingTextSize = readingTextSize
        self.readingEntry = readingEntry
        self.followsGlobalReplyPreferences = followsGlobalReplyPreferences
        self.onOpenMedia = onOpenMedia
        self.onOpenUser = onOpenUser
        self.onDisplayed = onDisplayed
        self.onOpenSubposts = onOpenSubposts
    }

    var body: some View {
        ZStack {
            SemanticColor.background
            if ContentRemovalVisibility.shared.contains(thread: store.threadID) {
                Text("主题已删除").font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                    .accessibilityIdentifier("content.deleted.thread")
            } else { content }
        }
        .background(SemanticColor.background)
        .navigationTitle("")
        .toolbar { forumToolbar }
        .task { await bookmarks?.load() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.state.snapshot != nil, !ContentRemovalVisibility.shared.contains(thread: store.threadID) {
                ThreadReaderReplyBar(imageLoader: imageLoader, accountAvatar: accountAvatar,
                                     threadID: store.threadID, readingControls: store,
                                     reload: { Task { await store.reload() } }, onCompose: {
                    if let snapshot = store.state.snapshot { composeTarget = .reply(snapshot: snapshot, readingEntry: readingEntry) }
                })
            }
        }
        .textComposer(target: $composeTarget) { await store.replySucceeded($0, entry: readingEntry) }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            ThreadReaderAccessibilityID.screen(store.threadID)
        )
#if UITESTING
        .accessibilityValue(store.isShowingCachedContent ? "content-source:cache" : "content-source:request")
#endif
        .onDisappear { Task { await store.saveReadingPosition() } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await store.saveReadingPosition() } }
        }
        .task(id: store.cacheContext) { await loadStoreAcrossProjection() }
        .task(id: replyPreferences?.replyQuery) { await loadStoreAcrossProjection() }
        .task(id: loadTaskID) {
            await loadStoreAcrossProjection()
        }
        .task(id: displayedThreadID) {
            await recordDisplayedThreadAcrossProjection()
        }
    }

    @ToolbarContentBuilder
    private var forumToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            forumToolbarItem.sharedBackgroundVisibility(.hidden)
        } else {
            forumToolbarItem
        }
    }

    private var forumToolbarItem: some ToolbarContent {
        // A title must not morph into the previous page's native back item.
        ToolbarItem(placement: .principal) {
            if let snapshot = store.state.snapshot {
                Button {
                    if let url = PublicContentURL.forum(snapshot.forumName) { openURL(url) }
                } label: {
                    ThreadReaderForumChip(snapshot: snapshot, imageLoader: imageLoader)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("thread-reader.open-forum")
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .initialLoading:
            InitialLoadingView(title: "正在加载帖子")
        case .initialFailure:
            FullPageErrorView(
                title: "帖子加载失败",
                message: "这篇帖子暂时不可用。",
                retry: requestRetry
            )
            .accessibilityIdentifier(
                ThreadReaderAccessibilityID.failure(store.threadID)
            )
        case let .loaded(snapshot),
             let .loadingNextPage(snapshot),
             let .nextPageFailure(snapshot):
            reader(snapshot)
        }
    }

    @ViewBuilder
    private func reader(_ snapshot: ThreadReaderSnapshot) -> some View {
        if let presentation = store.listPresentation {
            let readingSession = store.readingSession
            VirtualizedList(
                items: store.configuredRows(textSize: readingTextSize),
                backgroundColor: .systemBackground,
                accessibilityIdentifier:
                    ThreadReaderAccessibilityID.scroll(snapshot.threadID),
                restoredAnchor: store.readAnchor,
                contentVersion: VirtualListContentRevision(owner: ObjectIdentifier(store), revision: store.listRevision,
                                                           configuration: readingTextSize),
                initialRestorationScope: AnyHashable(ThreadReaderRestorationScope(
                    threadID: store.threadID, context: store.cacheContext, query: store.query)),
                onPrefetch: { rowIDs in
                    guard readingSession == store.readingSession, rowIDs.contains(where: {
                        presentation.prefetchRowIDs.contains($0)
                    }) else {
                        return
                    }
                    store.prefetchNextPage()
                    requestNextPage()
                },
                onScrollSettled: { anchor in
                    if readingSession == store.readingSession { store.setReadAnchor(anchor) }
                },
                onRefresh: { if readingSession == store.readingSession { await store.reload() } },
                rowContent: { configuredRow in
                    ThreadReaderRowView(
                        readingControls: store, replyPreferences: replyPreferences,
                        row: configuredRow.row,
                        imageLoader: imageLoader,
                        readingTextSize: configuredRow.readingTextSize,
                        onOpenMedia: onOpenMedia,
                        onOpenUser: onOpenUser,
                        onOpenSubposts: onOpenSubposts,
                        onOpenExternalLink: { intent in
                            if let url = URL(string: intent.destination.absoluteString) { openURL(url) }
                        },
                        onReply: { post in composeTarget = .reply(snapshot: snapshot, post: post, readingEntry: readingEntry) },
                        favoriteStore: favorites, bookmarkStore: bookmarks,
                        bookmarkTitle: snapshot.title, bookmarkForum: snapshot.forumName,
                        requestNextPage: requestNextPage
                    ).environment(\.contentActions, contentActions)
                }
            )
            .id(readingSession) // Only an explicit mode/page navigation starts a new list session.
            .background(SemanticColor.background)
            .accessibilityElement(children: .contain)
        } else {
            InitialLoadingView(title: "正在加载帖子")
        }
    }

    private var loadTaskID: ThreadReaderLoadTaskID {
        ThreadReaderLoadTaskID(
            threadID: store.threadID,
            retryGeneration: retryGeneration
        )
    }

    private var displayedThreadID: Int64? {
        store.state.snapshot?.threadID
    }

    private func requestRetry() {
        store.prepareRetry()
        retryGeneration &+= 1
    }

    private func requestNextPage() {
        Task { @MainActor in
            if store.refreshFailed { await store.reload() } else { await store.loadNextPage() }
        }
    }

    private func loadStoreAcrossProjection() async {
        let operation = Task { @MainActor in
            if followsGlobalReplyPreferences { await store.applyReplyPreferences(replyPreferences) }
            await store.loadIfNeeded()
        }
        await operation.value
    }

    private func recordDisplayedThreadAcrossProjection() async {
        let operation = Task { @MainActor in
            guard let snapshot = store.state.snapshot,
                  store.claimDisplayedThread(snapshot.threadID) else {
                return
            }
            await onDisplayed(snapshot)
        }
        await operation.value
    }
}

struct ThreadReaderConfiguredRow: Identifiable, Equatable, Sendable {
    let row: ThreadReaderRowModel
    let readingTextSize: ReadingTextSizePreference

    var id: ThreadReaderRowID {
        row.id
    }
}

struct ThreadReaderConfiguredRows {
    let revision: UInt64
    let textSize: ReadingTextSizePreference
    let rows: [ThreadReaderConfiguredRow]
}

private struct ThreadReaderLoadTaskID: Hashable {
    let threadID: Int64
    let retryGeneration: UInt64
}

@MainActor
struct ThreadReaderPaginationView: View {
    let pagination: ThreadReaderPaginationRowModel
    let requestNextPage: () -> Void

    @ViewBuilder
    var body: some View {
        switch pagination.state {
        case let .cached(hasMore, _):
            if hasMore {
                Button("已缓存内容 · 加载更多", action: requestNextPage)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier(ThreadReaderAccessibilityID.loadMore(pagination.threadID))
            } else {
                Text("已缓存内容 · 已经到底了")
                    .font(Typography.font(.caption)).foregroundStyle(SemanticColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        case .refreshFailure:
            Button("正在显示已缓存内容，刷新失败，点此重试", action: requestNextPage)
                .font(Typography.font(.caption)).foregroundStyle(SemanticColor.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("thread-reader.refresh-retry")
        case .end:
            PaginationFooter(state: .end, retry: {})
        case .failure:
            PaginationFooter(
                state: .failure,
                retry: requestNextPage
            )
        case .loading:
            PaginationFooter(state: .loading, retry: {})
        case .loadMore:
            Button("加载更多", action: requestNextPage)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(
                    ThreadReaderAccessibilityID.loadMore(
                        pagination.threadID
                    )
                )
        }
    }
}

enum ThreadReaderAccessibilityID {
    static func failure(_ threadID: Int64) -> String {
        "thread-reader.state.failure.t\(threadID)"
    }

    static func header(_ threadID: Int64) -> String {
        "thread-reader.header.t\(threadID)"
    }

    static func loadMore(_ threadID: Int64) -> String {
        "thread-reader.pagination.load-more.t\(threadID)"
    }

    static func post(_ source: ThreadContentSource) -> String {
        "thread-reader.post.t\(source.threadID).p\(source.postID)"
            + ".s\(source.scope.rawValue)"
    }

    static func screen(_ threadID: Int64) -> String {
        "thread-reader.screen.t\(threadID)"
    }

    static func subpost(_ source: ThreadContentSource) -> String {
        "thread-reader.subpost.t\(source.threadID).p\(source.postID)"
            + ".s\(source.scope.rawValue)"
    }

    static func scroll(_ threadID: Int64) -> String {
        "thread-reader.scroll.t\(threadID)"
    }
}

private struct ThreadReaderRestorationScope: Hashable {
    let threadID: Int64
    let context: ContentCacheContext
    let query: ThreadReadingQuery
}
