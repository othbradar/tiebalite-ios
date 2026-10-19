import SwiftUI

/// Secondary reading actions stay in the existing bottom ellipsis.
struct ThreadReadingMenu: View {
    @Bindable var store: ThreadReaderStore
    let url: URL
    let reload: () -> Void
    @State private var showsJump = false
    @State private var pageText = ""

    var body: some View {
        Menu {
            Button("跳页") { pageText = ""; showsJump = true }
                .accessibilityIdentifier("thread-reader.jump-page")
            Button("回到首楼") { Task { await store.returnToFirstPost() } }
                .accessibilityIdentifier("thread-reader.first-post")
            if let snapshot = store.state.snapshot {
                ContentDeleteAction(target: .init(kind: .thread, threadID: snapshot.threadID))
                FavoriteAction(entry: .init(
                    target: .init(threadID: snapshot.threadID,
                                  postID: store.listPresentation?.rows.first { $0.id == store.readAnchor }?.post?.source.postID
                                      ?? snapshot.posts.first?.id.postID),
                    title: snapshot.title, forumName: snapshot.forumName, status: 1, isDeleted: false))
                BookmarkAction(entry: .init(target: .init(threadID: snapshot.threadID, postID: nil),
                                            title: snapshot.title, forumName: snapshot.forumName, floor: nil))
            }
            Divider()
            LinkActionsContent(url: url, identifier: "thread-reader.compose.more", reload: reload)
        } label: {
            Label("更多", systemImage: "ellipsis")
                .font(TiebaParityTokens.contentActionIconFont)
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
        }
#if UITESTING
        .accessibilityValue("\(store.query.cacheKey);page:\(store.state.snapshot?.currentPage ?? 0);anchor:\(anchorPostID)")
#endif
        .modifier(ContentDeletionPreparation(target: .init(kind: .thread, threadID: store.threadID),
                                             authorID: store.state.snapshot?.author.rawUserID ?? 0))
        .disabled(store.isNavigating)
        .accessibilityIdentifier("thread-reader.compose.more")
        .alert("跳页", isPresented: $showsJump) {
            TextField("页码", text: $pageText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("thread-reader.page-input")
            Button("取消", role: .cancel) {}
            Button("跳转") {
                Task { await store.jumpToPage(Int(pageText) ?? 0) }
            }
            .accessibilityIdentifier("thread-reader.jump-confirm")
        } message: {
            if let total = store.state.snapshot?.totalPage {
                Text("第 \(store.state.snapshot?.currentPage ?? 1) / \(total) 页")
            }
        }
        .alert("无法跳转", isPresented: Binding(
            get: { store.navigationMessage != nil }, set: { if !$0 { store.navigationMessage = nil } }
        )) {
            Button("好", role: .cancel) { store.navigationMessage = nil }
        } message: { Text(store.navigationMessage ?? "") }
    }

#if UITESTING
    private var anchorPostID: Int64 {
        store.listPresentation?.rows.first { $0.id == store.readAnchor }?.post?.source.postID ?? 0
    }
#endif
}
