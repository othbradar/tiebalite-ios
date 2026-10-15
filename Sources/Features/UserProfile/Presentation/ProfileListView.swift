import SwiftUI

@MainActor
struct ProfileListView: View {
    @Bindable var store: ProfileListStore
    let imageLoader: any ImageLoading
    var blocking: LocalBlockingStore?
    let open: (RouteIdentity) -> Void

    var body: some View {
        Group {
            if !store.rows.isEmpty {
                VirtualizedList(items: store.rows, backgroundColor: .systemBackground,
                                accessibilityIdentifier: "profile.\(store.route.section.rawValue).list",
                                restoredAnchor: store.anchor, onScrollSettled: store.setAnchor,
                                onRefresh: { await store.refresh() }, rowContent: row)
            } else {
                switch store.state {
                case .failed, .refreshFailure:
                    FullPageErrorView(title: "加载失败", message: "请重试。", retry: { Task { await store.refresh() } })
                case .privateContent:
                    Text("该内容未公开").font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                case .contentUnavailable:
                    Text("暂无可查看的关注吧").font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                        .accessibilityIdentifier("profile.forums.unavailable")
                case .empty:
                    Text("暂无内容").font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
                default: InitialLoadingView(title: "正在加载")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle(store.route.section.title).navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.\(store.route.section.rawValue).screen")
        .task(id: store.activationScope) { store.setBlocked(blocking?.ids ?? []); await store.activate() }
        .onChange(of: blocking?.revision) { _, _ in store.setBlocked(blocking?.ids ?? []) }
        .onDisappear { store.cancel() }
    }

    @ViewBuilder private func row(_ value: ProfileListRow) -> some View {
        switch value.content {
        case let .post(post):
            ForumThreadFeedRow(row: .init(thread: post.summary, forumID: nil), imageLoader: imageLoader,
                               accessibilityPrefix: "profile.\(store.route.section.rawValue)", rowAccessibilityID: "profile.post.\(post.id)") {
                if store.route.section == .replies, let pid = post.postID {
                    open(.profileReply(.init(threadID: post.summary.threadID, postID: pid)))
                } else if let tid = ThreadID(post.summary.threadID) { open(.thread(tid)) }
            }
        case let .forum(forum):
            Button {
                if let route = ForumRoute(forumID: forum.id, forumName: forum.name) { open(.forum(route)) }
            } label: {
                HomeFollowedForumRow(forum: forum, avatarResource: forum.avatarResource, imageLoader: imageLoader, showsHotCount: false)
            }.buttonStyle(.plain).accessibilityIdentifier("profile.forum.\(forum.id)")
        case let .footer(state):
            if store.state == .refreshFailure {
                Button("刷新失败，重试") { Task { await store.refresh() } }
                    .font(.caption).frame(minHeight: 44).accessibilityIdentifier("profile.refresh-retry")
            } else if state == .idle {
                Button("加载更多") { Task { await store.loadMore() } }
                    .font(.caption).frame(minHeight: 44).accessibilityIdentifier("profile.load-more")
            } else { PaginationFooter(state: state, retry: { Task { await store.loadMore() } }) }
        }
    }
}

@MainActor
struct LocalBlockedUsersView: View {
    @Bindable var store: LocalBlockingStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if store.error { Text("屏蔽列表读写失败").foregroundStyle(SemanticColor.secondaryText) } else if store.entries.isEmpty {
                    Text("暂无本机屏蔽用户").foregroundStyle(SemanticColor.secondaryText)
                }
                ForEach(store.entries) { entry in
                    HStack {
                        Text(entry.name)
                        Spacer()
                        Button("取消屏蔽") { Task { await store.set(entry, blocked: false) } }
                            .accessibilityIdentifier("profile.unblock.\(entry.id)")
                    }
                }
            }
            .navigationTitle("本机屏蔽").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .task { await store.activate() }
            .accessibilityIdentifier("profile.blocked-users")
        }
    }
}
