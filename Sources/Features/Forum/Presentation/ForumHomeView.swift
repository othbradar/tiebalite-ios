import SwiftUI

@MainActor
struct ForumHomeView: View {
    @Bindable var store: ForumHomeStore
    let route: ForumRoute
    var imageLoader: any ImageLoading = DisabledImageLoader()
    let onOpenThread: (ForumThreadSummary) -> Void
    var onDisplayed: (ForumSummary) async -> Void = { _ in }
    var onOpenSearch: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var composeTarget: TextComposeTarget?

    var body: some View {
        VStack(spacing: 0) {
            if let forum = store.state.displayedForum {
                ForumHeaderView(forum: forum, imageLoader: imageLoader)
                ForumTabsView(store: store)
                TiebaFlatDivider(inset: 0)
                pager
            } else {
                ForumThreadPageView(store: store, pageID: .latest, imageLoader: imageLoader, onOpenThread: onOpenThread)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppAccessibilityID.routeForum)
        .task(id: route) {
            let operation = Task { @MainActor in await store.synchronize(with: route) }
            await operation.value
        }
        .task(id: store.selectedPage) {
            let operation = Task { @MainActor in await store.activateSelectedPage() }
            await operation.value
        }
        .task(id: store.state.displayedForum?.forumID) {
            guard let forum = store.state.displayedForum, let id = forum.forumID,
                  store.claimDisplayedForum(id) else { return }
            await onDisplayed(forum)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("搜索", systemImage: "magnifyingglass", action: onOpenSearch)
                    .accessibilityIdentifier("forum-home.search")
                Button("发帖", systemImage: "plus") {
                    guard let forum = store.state.displayedForum else { return }
                    composeTarget = .init(kind: .thread, forumID: forum.forumID ?? 0, forumName: forum.name)
                }
                    .accessibilityIdentifier("forum-home.compose")
                Menu("更多", systemImage: "ellipsis") {
                    Button("重新加载", systemImage: "arrow.clockwise") {
                        Task { await (store.pageStore(for: store.selectedPage ?? .latest) ?? store).reload() }
                    }
                    .accessibilityIdentifier(ForumHomeAccessibilityID.reload)
                }
                .accessibilityIdentifier("forum-home.more")
            }
            .tiebaFlatToolbarItem()
        }
        .textComposer(target: $composeTarget) { _ in
            await (store.pageStore(for: store.selectedPage ?? .latest) ?? store).reload()
        }
    }

    private var pager: some View {
        PagerContainer(
            pageIDs: store.pageIDs, selection: $store.selectedPage,
            backgroundColor: .systemBackground, reduceMotion: reduceMotion,
            externalSelectionGeneration: $store.selectionGeneration,
            contentGeneration: { _ in 0 },
            content: { pageID in
            if let page = store.pageStore(for: pageID) {
                ForumThreadPageView(store: page, pageID: pageID, imageLoader: imageLoader, onOpenThread: onOpenThread)
                    // Pager hosts each page separately; extend its reading viewport as well.
                    .ignoresSafeArea(.container, edges: .bottom)
            }
        })
        .accessibilityIdentifier("forum-home.pager")
    }
}

@MainActor
struct ForumThreadPageView: View {
    @Bindable var store: ForumHomeStore
    let pageID: ForumPageID
    let imageLoader: any ImageLoading
    let onOpenThread: (ForumThreadSummary) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if pageID == .good, let forum = store.state.displayedForum {
                ForumGoodChips(store: store, categories: forum.navigation.goodCategories)
            }
            content
        }
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("forum-home.page.\(pageID.accessibilityKey)")
    }

    @ViewBuilder
    private var content: some View {
        if let presentation = store.listPresentation {
            VirtualizedList(
                items: presentation.rows, backgroundColor: .systemBackground,
                accessibilityIdentifier: ForumHomeAccessibilityID.list,
                restoredAnchor: store.scrollAnchor.map(ForumHomeRowID.thread),
                onPrefetch: { ids in
                    guard ids.contains(where: { presentation.prefetchRowIDs.contains($0) }) else { return }
                    Task { await store.loadNextPage() }
                },
                onScrollSettled: store.setScrollAnchor,
                rowContent: { row in
                ForumHomeRowView(row: row, imageLoader: imageLoader, onOpenThread: onOpenThread,
                                 requestReload: { Task { await store.reload() } },
                                 requestNextPage: { Task { await store.loadNextPage() } })
            })
        } else if case .initialFailure = store.state {
            FullPageErrorView(title: "吧首页加载失败", message: "网络或服务暂时不可用。") {
                Task { await store.reload() }
            }
            .accessibilityIdentifier(ForumHomeAccessibilityID.failure)
        } else {
            InitialLoadingView(title: "正在加载吧首页")
                .accessibilityIdentifier(ForumHomeAccessibilityID.initialLoading)
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

    static func row(_ threadID: Int64) -> String { "forum-home.row.t\(threadID)" }
    static func thumbnail(threadID: Int64, ordinal: Int) -> String { "forum-home.thumbnail.t\(threadID).i\(ordinal)" }
}
