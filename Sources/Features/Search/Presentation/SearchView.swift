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
    static func forum(_ forumID: Int64) -> String { "search.forum.\(forumID)" }
    static func thread(_ threadID: Int64) -> String { "search.thread.\(threadID)" }
}

@MainActor
struct SearchView: View {
    @Bindable var store: SearchStore
    let imageLoader: any ImageLoading
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    let onOpenForum: (ForumSearchResult) -> Void
    let onOpenThread: (ThreadSearchResult) -> Void
    let onOpenUser: (UserProfileRoute) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if store.scope == .global { searchForm }
            if store.scope == .global { typeTabs }
            if store.scope != .global, store.submittedKeyword != nil {
                ForumSearchControls(store: store, resignFocus: dismissSearchKeyboard)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .task { if store.scope != .global { await store.loadHistory() } }
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if store.scope != .global {
                ToolbarItem(placement: .principal) { searchForm }
                cancelSearchToolbarItem
            }
        }
        .navigationTitle(store.scope == .global ? searchTitle : "")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SearchAccessibilityID.root)
    }

    @ToolbarContentBuilder
    private var cancelSearchToolbarItem: some ToolbarContent {
        if #available(iOS 26, *) {
            // A plain cancel action matches the search reference and avoids the glass
            // platter's opaque hosted-label snapshot during push/pop.
            ToolbarItem(placement: .topBarTrailing) { cancelSearchButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { cancelSearchButton }
        }
    }

    private var cancelSearchButton: some View {
        Button("取消") { dismiss() }
            .font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
            .frame(minWidth: 44, minHeight: 44)
            .buttonStyle(.plain)
            .accessibilityIdentifier("forum-home.search.close")
    }

    private var searchForm: some View {
        TiebaSearchBoxSurface(placement: store.scope == .global ? .content : .navigationBar) {
            HStack(spacing: 16) {
                if store.scope != .global {
                    Text("本吧").font(.subheadline.bold()).foregroundStyle(SemanticColor.primaryText)
                        .accessibilityLabel(searchTitle)
                    Rectangle().fill(SemanticColor.secondaryText.opacity(0.2)).frame(width: 1, height: 16)
                }
                Button(action: requestSubmit) {
                    Image(systemName: "magnifyingglass").font(.title3)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .padding(-12) // Keep the home icon's visual footprint with a 44pt hit target.
                .accessibilityLabel("搜索")
                .accessibilityIdentifier(SearchAccessibilityID.submit)
                TextField(store.scope == .global ? "发现更多" : searchTitle, text: Binding(
                    get: { store.draftKeyword }, set: { store.setDraftKeyword($0) }
                ))
                .font(.subheadline)
                .foregroundStyle(SemanticColor.primaryText)
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(requestSubmit)
                .accessibilityIdentifier(SearchAccessibilityID.field)
                if !store.draftKeyword.isEmpty {
                    Button {
                        store.setDraftKeyword("")
                        isSearchFieldFocused = true
                    } label: {
                        Image(systemName: "xmark").font(.subheadline)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .padding(-12)
                    .accessibilityLabel("清空搜索词")
                    .accessibilityIdentifier("search.clear")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, store.scope == .global ? 16 : 0)
        .padding(.vertical, store.scope == .global ? 8 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.box")
    }

    private var searchTitle: String {
        guard case let .forum(forum) = store.scope else { return "搜索" }
        let name = forum.forumName.rawValue
        return "在\(name.hasSuffix("吧") ? name : name + "吧")内搜索"
    }

    private var typeTabs: some View {
        HStack(spacing: 0) {
            typeTab(.forums, title: "搜吧")
            typeTab(.threads, title: "搜帖")
            typeTab(.users, title: "搜人")
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func typeTab(_ type: SearchResultType, title: String) -> some View {
        let selected = store.selectedType == type
        Group {
            if type == .threads, selected {
                Menu {
                    ForEach(SearchSort.allCases, id: \.self) { sort in
                        Button {
                            dismissSearchKeyboard()
                            Task { await store.selectSort(sort) }
                        } label: {
                            if store.selectedSort == sort {
                                Label(sort.title, systemImage: "checkmark")
                            } else {
                                Text(sort.title)
                            }
                        }
                        .accessibilityIdentifier("search.sort.\(sort.rawValue)")
                    }
                } label: {
                    typeTabLabel(title, selected: true, showsSort: true)
                }
                .accessibilityValue(store.selectedSort.title)
            } else {
                Button {
                    dismissSearchKeyboard()
                    Task { await store.selectType(type) }
                } label: {
                    typeTabLabel(title, selected: selected, showsSort: false)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("search.type.\(type.rawValue)")
    }

    private func typeTabLabel(_ title: String, selected: Bool, showsSort: Bool) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Text(title).font(.subheadline.weight(selected ? .bold : .regular))
                if showsSort { Image(systemName: "chevron.down").font(.caption2.weight(.semibold)) }
            }
            Capsule().fill(selected ? SemanticColor.primaryText : .clear).frame(width: 18, height: 3)
        }
        .foregroundStyle(selected ? SemanticColor.primaryText : SemanticColor.secondaryText)
        .frame(minWidth: 76, minHeight: 44)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle:
            if store.scope == .global {
                Text("输入关键词搜索").font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForumSearchHistoryView(store: store) { requestSubmit() }
            }
        case .searching:
            InitialLoadingView(title: "正在搜索").accessibilityIdentifier(SearchAccessibilityID.loading)
        case .empty:
            Text(emptyMessage)
                .font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(SearchAccessibilityID.empty)
        case .failed(_, _, nil):
            FullPageErrorView(title: store.scope == .global ? "搜索失败" : "吧内搜索失败", message: "网络或服务暂时不可用。", retry: requestRetry)
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
                backgroundColor: store.scope == .global ? .systemBackground : .secondarySystemBackground,
                accessibilityIdentifier: SearchAccessibilityID.list,
                restoredAnchor: store.scrollAnchor,
                initialRestorationScope: presentation.query,
                onPrefetch: { rowIDs in
                    guard store.query == presentation.query, case .loaded = store.state,
                          rowIDs.contains(where: { presentation.prefetchRowIDs.contains($0) }) else { return }
                    requestNextPage()
                },
                onScrollSettled: { store.setScrollAnchor($0, for: presentation.query) },
                rowContent: { row in
                    if store.scope != .global, case let .thread(thread) = row.content {
                        ForumSearchResultRow(row: thread, keyword: presentation.query.keyword.rawValue,
                                             imageLoader: imageLoader, open: { onOpenThread(thread.result) })
                    } else {
                        SearchRowView(row: row, imageLoader: imageLoader, onOpenForum: onOpenForum,
                                      onOpenThread: onOpenThread, onOpenUser: onOpenUser, retryNextPage: requestNextPage)
                    }
                }
            )
            // A different query is a different list viewport; rows and caches keep their business identities.
            .id(presentation.query)
            .accessibilityElement(children: .contain)
        } else {
            InitialLoadingView(title: "正在搜索")
        }
    }

    private var emptyMessage: String {
        switch store.selectedType {
        case .forums: "没有匹配的贴吧"
        case .threads: "没有匹配的帖子"
        case .users: "没有匹配的用户"
        }
    }

    private func requestSubmit() {
        dismissSearchKeyboard()
        Task { await store.submit() }
    }
    private func dismissSearchKeyboard() {
        isSearchFieldFocused = false
        // The iPad navigation toolbar hosts its field separately from the content focus scope.
        // End the active input session on explicit search/filter actions before changing the viewport.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    private func requestRetry() { Task { await store.retry() } }
    private func requestNextPage() { Task { await store.loadNextPage() } }
}

private extension SearchSort {
    var title: String {
        switch self {
        case .newest: "新帖在前"
        case .oldest: "旧帖在前"
        case .relevance: "相关度"
        }
    }
}
