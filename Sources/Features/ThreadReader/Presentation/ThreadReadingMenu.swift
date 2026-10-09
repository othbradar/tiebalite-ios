import SwiftUI

/// Uses the existing bottom ellipsis; no additional persistent controls or explanatory labels.
struct ThreadReadingMenu: View {
    @Bindable var store: ThreadReaderStore
    let url: URL
    let reload: () -> Void
    @State private var showsJump = false
    @State private var pageText = ""

    var body: some View {
        Menu {
            Button(store.query.onlyAuthor ? "查看全部" : "只看楼主") {
                var query = store.query
                query.onlyAuthor.toggle()
                Task { await store.selectQuery(query) }
            }
            .accessibilityIdentifier("thread-reader.only-author")
            Button(store.query.order == .ascending ? "倒序查看" : "正序查看") {
                var query = store.query
                query.order = query.order == .ascending ? .descending : .ascending
                Task { await store.selectQuery(query) }
            }
            .accessibilityIdentifier("thread-reader.reverse")
            Button("跳页") { pageText = ""; showsJump = true }
                .accessibilityIdentifier("thread-reader.jump-page")
            Button("回到首楼") { Task { await store.returnToFirstPost() } }
                .accessibilityIdentifier("thread-reader.first-post")
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
