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
    let onOpenForum: (ForumSearchResult) -> Void
    let onOpenThread: (ThreadSearchResult) -> Void
    let onOpenUser: (UserProfileRoute) -> Void

    var body: some View {
        VStack(spacing: 0) {
            searchForm
            typeTabs
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SearchAccessibilityID.root)
    }

    private var searchForm: some View {
        TiebaSearchBoxSurface {
            HStack(spacing: 16) {
                Button(action: requestSubmit) {
                    Image(systemName: "magnifyingglass").font(.title3)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .padding(-12) // Keep the home icon's visual footprint with a 44pt hit target.
                .accessibilityLabel("搜索")
                .accessibilityIdentifier(SearchAccessibilityID.submit)
                TextField("发现更多", text: Binding(
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
        .padding(.horizontal, 16).padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.box")
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
                            isSearchFieldFocused = false
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
                    isSearchFieldFocused = false
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
            Text("输入关键词搜索").font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .searching:
            InitialLoadingView(title: "正在搜索").accessibilityIdentifier(SearchAccessibilityID.loading)
        case .empty:
            Text(emptyMessage)
                .font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(SearchAccessibilityID.empty)
        case .failed(_, _, nil):
            FullPageErrorView(title: "搜索失败", message: "网络或服务暂时不可用。", retry: requestRetry)
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
                initialRestorationScope: presentation.query,
                onPrefetch: { rowIDs in
                    guard store.query == presentation.query, case .loaded = store.state,
                          rowIDs.contains(where: { presentation.prefetchRowIDs.contains($0) }) else { return }
                    requestNextPage()
                },
                onScrollSettled: { store.setScrollAnchor($0, for: presentation.query) },
                rowContent: { row in
                    SearchRowView(row: row, imageLoader: imageLoader, onOpenForum: onOpenForum,
                                  onOpenThread: onOpenThread, onOpenUser: onOpenUser, retryNextPage: requestNextPage)
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
        isSearchFieldFocused = false
        Task { await store.submit() }
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
