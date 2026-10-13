import SwiftUI

extension EnvironmentValues {
    @Entry var bookmarks: BookmarkStore?
}

struct BookmarkFeedbackHost: ViewModifier {
    @Bindable var store: BookmarkStore
    func body(content: Content) -> some View {
        content.alert(store.feedback ?? "本机书签", isPresented: Binding(
            get: { store.feedback != nil }, set: { if !$0 { store.feedback = nil } }
        )) { Button("好", role: .cancel) { store.feedback = nil } }
    }
}

struct BookmarkAction: View {
    @Environment(\.bookmarks) private var bookmarks
    let entry: ThreadBookmark
    var store: BookmarkStore?
    var isFloor = false
    var body: some View {
        if let bookmarks = store ?? bookmarks {
            Button {
                Task {
                    if !isFloor && bookmarks.contains(entry.id) { await bookmarks.remove(threadID: entry.id) } else { await bookmarks.save(entry) }
                }
            } label: {
                Text(isFloor ? "本机书签到此楼" : (bookmarks.contains(entry.id) ? "移除本机书签" : "加入本机书签"))
            }
            .disabled(bookmarks.isBusy)
            .accessibilityIdentifier(isFloor ? "bookmark.floor.\(entry.target.postID ?? 0)" : "bookmark.thread")
        }
    }
}

struct BookmarkListView: View {
    @Bindable var store: BookmarkStore
    let open: (ThreadBookmarkTarget) -> Void
    var body: some View {
        Group {
            if store.state == .failed && store.entries.isEmpty {
                FullPageErrorView(title: "本机书签读取失败", message: "请确认已登录后重试。", retry: { Task { await store.refresh() } })
            } else if store.state == .idle || (store.state == .loading && store.entries.isEmpty) {
                InitialLoadingView(title: "正在读取书签")
            } else if store.entries.isEmpty {
                EmptyStateView(title: "暂无本机书签", message: "可从帖子更多菜单添加。", systemImage: "bookmark")
            } else {
                List {
                    ForEach(store.entries) { entry in
                        Button { open(entry.target) } label: {
                            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                Text(entry.title).font(Typography.font(.headline)).foregroundStyle(SemanticColor.primaryText)
                                HStack {
                                    Text(entry.forumName)
                                    if let floor = entry.floor { Text("第 \(floor) 楼") }
                                }
                                .font(Typography.font(.caption)).foregroundStyle(SemanticColor.secondaryText)
                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("bookmarks.row.\(entry.id)")
                        .contextMenu { Button("移除", role: .destructive) { Task { await store.remove(threadID: entry.id) } } }
                        .swipeActions {
                            Button("移除", role: .destructive) { Task { await store.remove(threadID: entry.id) } }
                                .disabled(store.isBusy)
                        }
                        .listRowBackground(SemanticColor.background)
                    }
                    if store.hasMore {
                        Button("加载更多") { store.loadMore() }.accessibilityIdentifier("bookmarks.load-more")
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
                .refreshable { await store.refresh() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle("本机书签").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("bookmarks.screen")
        .task { await store.load() }
    }
}

@MainActor
enum BookmarkNavigation {
    static func open(_ target: ThreadBookmarkTarget, in reader: ThreadReaderStore) async -> Bool {
        guard target.threadID == reader.threadID else { return false }
        if let postID = target.postID {
            await reader.locatePost(postID)
            return reader.navigationMessage == nil && reader.listPresentation?.rows.contains { $0.post?.source.postID == postID } == true
        }
        await reader.returnToFirstPost()
        return reader.navigationMessage == nil && reader.state.snapshot?.posts.first?.floorNumber == 1
    }
}
