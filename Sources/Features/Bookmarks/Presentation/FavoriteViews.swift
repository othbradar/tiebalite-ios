import SwiftUI

extension EnvironmentValues { @Entry var favorites: FavoriteStore? }

struct FavoriteFeedbackHost: ViewModifier {
    @Bindable var store: FavoriteStore
    func body(content: Content) -> some View {
        content.alert(store.feedback ?? "收藏", isPresented: Binding(
            get: { store.feedback != nil }, set: { if !$0 { store.feedback = nil } }
        )) { Button("好", role: .cancel) { store.feedback = nil } }
    }
}

struct FavoriteAction: View {
    @Environment(\.favorites) private var favorites
    let entry: ThreadFavorite
    var store: FavoriteStore?
    var isFloor = false
    var body: some View {
        if let favorites = store ?? favorites {
            Button {
                Task {
                    if !isFloor && favorites.contains(entry.id) { await favorites.remove(entry.id) } else { await favorites.save(entry) }
                }
            } label: { Text(isFloor ? "收藏到此楼" : (favorites.contains(entry.id) ? "取消收藏" : "收藏")) }
                .disabled(favorites.isBusy || entry.target.postID == nil)
                .accessibilityIdentifier(isFloor ? "favorite.floor.\(entry.target.postID ?? 0)" : "favorite.thread")
        }
    }
}

struct FavoriteListView<RowContent: View>: View {
    @Bindable var store: FavoriteStore
    let open: (ThreadBookmarkTarget) -> Void
    @ViewBuilder let rowContent: (ThreadFavorite, @escaping () -> Void) -> RowContent
    @Environment(\.scenePhase) private var scenePhase
    @State private var targetUnavailable = false

    var body: some View {
        List {
            if store.entries.isEmpty {
                Group {
                    if store.state == .idle || store.state == .loading {
                        InitialLoadingView(title: "正在读取收藏")
                    } else if store.state == .failed {
                        FullPageErrorView(title: "收藏同步失败", message: "请确认已登录后重试。", retry: { Task { await store.refresh() } })
                    } else {
                        Text("暂无收藏")
                            .font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                            .accessibilityIdentifier("favorites.empty")
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                }
                // These are page states, not a bordered placeholder post.
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            ForEach(store.entries) { entry in
                VStack(spacing: 0) {
                    rowContent(entry) {
                        if entry.isDeleted { targetUnavailable = true } else { open(entry.target) }
                    }
                }
                .listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
                .listRowBackground(SemanticColor.background)
                .swipeActions {
                    Button("取消收藏", role: .destructive) { Task { await store.remove(entry.id) } }.disabled(store.isBusy)
                }
                .contextMenu {
                    Button("取消收藏", role: .destructive) { Task { await store.remove(entry.id) } }.disabled(store.isBusy)
                }
            }
            if store.refreshFailed && !store.entries.isEmpty {
                Button("同步失败，点此重试") { Task { await store.refresh() } }.disabled(store.isBusy)
            }
            if store.hasMore {
                Button("加载更多") { Task { await store.loadMore() } }
                    .disabled(store.isBusy).accessibilityIdentifier("favorites.load-more")
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(SemanticColor.background)
        .navigationTitle("收藏").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("favorites.screen")
        .refreshable { await store.refresh() }
        .task(id: scenePhase) { if scenePhase == .active { await store.refresh() } }
        .alert("帖子暂不可用", isPresented: $targetUnavailable) { Button("好", role: .cancel) {} }
    }
}
