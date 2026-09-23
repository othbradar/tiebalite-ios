import SwiftUI
import UIKit

@MainActor
struct ThreadReaderView: View {
    @Bindable var store: ThreadReaderStore
    let imageLoader: any ImageLoading
    let readingTextSize: ReadingTextSizePreference
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let onOpenUser: (UserProfileRoute) -> Void
    let onDisplayed: (ThreadReaderSnapshot) async -> Void
    let onOpenSubposts: (ThreadContentSource) -> Void

    @State private var retryGeneration: UInt64 = 0
    @State private var showsUnavailableAction = false

    init(
        store: ThreadReaderStore,
        imageLoader: any ImageLoading,
        readingTextSize: ReadingTextSizePreference = .standard,
        onOpenMedia: @escaping (ThreadMediaIntent) -> Void,
        onOpenUser: @escaping (UserProfileRoute) -> Void = { _ in },
        onDisplayed: @escaping (ThreadReaderSnapshot) async -> Void = { _ in },
        onOpenSubposts: @escaping (ThreadContentSource) -> Void = { _ in }
    ) {
        self.store = store
        self.imageLoader = imageLoader
        self.readingTextSize = readingTextSize
        self.onOpenMedia = onOpenMedia
        self.onOpenUser = onOpenUser
        self.onDisplayed = onDisplayed
        self.onOpenSubposts = onOpenSubposts
    }

    var body: some View {
        ZStack {
            SemanticColor.background
            content
        }
        .background(SemanticColor.background)
        .navigationTitle("")
        .toolbar { forumToolbar }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.state.snapshot != nil {
                ThreadReaderReplyBar(imageLoader: imageLoader) { showsUnavailableAction = true }
            }
        }
        .alert("功能暂未开放", isPresented: $showsUnavailableAction) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("当前支持只读浏览，评论、点赞等功能暂未开放。")
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            ThreadReaderAccessibilityID.screen(store.threadID)
        )
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
        ToolbarItem(placement: .topBarLeading) {
            if let snapshot = store.state.snapshot {
                ThreadReaderForumChip(snapshot: snapshot, imageLoader: imageLoader)
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
            VirtualizedList(
                items: presentation.rows.map {
                    ThreadReaderConfiguredRow(
                        row: $0,
                        readingTextSize: readingTextSize
                    )
                },
                backgroundColor: .systemBackground,
                accessibilityIdentifier:
                    ThreadReaderAccessibilityID.scroll(snapshot.threadID),
                restoredAnchor: store.readAnchor,
                onPrefetch: { rowIDs in
                    guard rowIDs.contains(where: {
                        presentation.prefetchRowIDs.contains($0)
                    }) else {
                        return
                    }
                    requestNextPage()
                },
                onScrollSettled: store.setReadAnchor,
                rowContent: { configuredRow in
                    ThreadReaderRowView(
                        row: configuredRow.row,
                        imageLoader: imageLoader,
                        readingTextSize: configuredRow.readingTextSize,
                        onOpenMedia: onOpenMedia,
                        onOpenUser: onOpenUser,
                        onOpenSubposts: onOpenSubposts,
                        onReadOnlyAction: { showsUnavailableAction = true },
                        requestNextPage: requestNextPage
                    )
                }
            )
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
            await store.loadNextPage()
        }
    }

    private func loadStoreAcrossProjection() async {
        let operation = Task { @MainActor in
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

private struct ThreadReaderConfiguredRow: Identifiable, Equatable, Sendable {
    let row: ThreadReaderRowModel
    let readingTextSize: ReadingTextSizePreference

    var id: ThreadReaderRowID {
        row.id
    }
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
