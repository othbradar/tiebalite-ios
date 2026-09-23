import SwiftUI

@MainActor
struct FollowedForumsView: View {
    @Bindable var store: FollowedForumsStore
    let sessionAccess: FollowedForumsSessionAccess
    let imageLoader: any ImageLoading
    let recentForums: [RecentForum]
    let openLogin: () -> Void
    let openSearch: () -> Void
    let openForum: (FollowedForum) -> Void
    let openRecentForum: (ForumRoute) -> Void

    @State private var historyExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            HomeSearchBox(action: openSearch)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(FollowedForumsAccessibilityID.root)
        .task(id: sessionAccess) { await synchronizeStoreAcrossProjection() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 12) {
                    // Session currently exposes no verified account portrait.
                    TiebaAvatarView(resource: nil, imageLoader: imageLoader, size: 32,
                                    accessibilityLabel: "当前账户头像暂不可用")
                    Text("首页").font(.title3.bold())
                        .accessibilityIdentifier("home.title")
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .tiebaFlatToolbarItem()
            if store.state.canReload {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("重新加载", systemImage: "arrow.clockwise", action: requestReload)
                        .accessibilityIdentifier(FollowedForumsAccessibilityID.reload)
                }
                .tiebaFlatToolbarItem()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case let .loaded(forums):
            forumList(forums)
        case let .refreshing(forums):
            forumList(forums, status: .loading)
        case let .refreshFailure(forums, _):
            forumList(forums, status: .failure)
        default:
            VStack(spacing: 0) {
                if !recentForums.isEmpty {
                    HomeRecentForumsRow(
                        forums: recentForums, expanded: historyExpanded, imageLoader: imageLoader,
                        toggle: { historyExpanded.toggle() }, openForum: openRecentForum
                    )
                }
                stateContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch store.state {
        case .signedOut:
            stateMessage("登录后查看关注的吧", detail: "使用现有网页登录即可读取你的关注列表。",
                         identifier: FollowedForumsAccessibilityID.signedOut, button: "登录", action: openLogin)
        case .expired:
            stateMessage("登录已失效", detail: "请重新登录后再加载关注列表。",
                         identifier: FollowedForumsAccessibilityID.expired, button: "重新登录", action: openLogin)
        case .initialFailure:
            stateMessage("关注列表加载失败", detail: "网络或服务暂时不可用。",
                         identifier: FollowedForumsAccessibilityID.failure, button: "重试", action: requestReload)
        case .empty:
            stateMessage("暂未关注贴吧", detail: "当前账号没有可显示的关注吧。",
                         identifier: FollowedForumsAccessibilityID.empty)
        case .initialLoading, .signingIn:
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { _ in HomeForumSkeleton() }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("正在加载关注的吧")
            .accessibilityIdentifier(store.state == .signingIn
                                    ? FollowedForumsAccessibilityID.signingIn
                                    : FollowedForumsAccessibilityID.initialLoading)
        case .loaded, .refreshing, .refreshFailure:
            EmptyView()
        }
    }

    private func stateMessage(
        _ title: String, detail: String, identifier: String,
        button: String? = nil, action: @escaping () -> Void = {}
    ) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(SemanticColor.secondaryText)
            if let button {
                Button(button, action: action)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier(button == "重试"
                                             ? FollowedForumsAccessibilityID.reload
                                             : FollowedForumsAccessibilityID.login)
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func forumList(
        _ forums: [FollowedForum], status: FollowedForumsRetainedStatus? = nil
    ) -> some View {
        let presentation = FollowedForumsListPresentation(
            forums: forums, recent: recentForums, expanded: historyExpanded, status: status
        )
        return VirtualizedList(
            items: presentation.rows,
            backgroundColor: .systemBackground,
            accessibilityIdentifier: FollowedForumsAccessibilityID.list,
            restoredAnchor: presentation.restoredRowID(for: store.scrollAnchor),
            onScrollSettled: { rowID in
                guard let forumID = presentation.forumAnchor(for: rowID) else { return }
                store.setScrollAnchor(forumID)
            },
            rowContent: listRow
        )
    }

    @ViewBuilder
    private func listRow(_ row: FollowedForumsRowModel) -> some View {
        switch row.content {
        case let .recent(forums, expanded):
            HomeRecentForumsRow(
                forums: forums, expanded: expanded, imageLoader: imageLoader,
                toggle: { historyExpanded.toggle() }, openForum: openRecentForum
            )
        case .heading:
            HStack {
                HomeSectionLabel(title: "关注")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        case .status(.loading):
            InlineLoadingView(title: "正在重新加载").padding(12)
        case .status(.failure):
            InlineErrorView(message: "重新加载失败，已保留原列表。", retry: requestReload).padding(12)
        case let .forum(forum):
            VStack(spacing: 0) {
                Button { openForum(forum) } label: {
                    HomeFollowedForumRow(forum: forum, avatarResource: row.avatarResource, imageLoader: imageLoader)
                }
                .buttonStyle(.plain)
                .accessibilityHint("打开吧首页")
                .accessibilityIdentifier(FollowedForumsAccessibilityID.row(forum.forumID))
                TiebaFlatDivider()
            }
        }
    }

    private func requestReload() {
        Task { await store.reload() }
    }

    private func synchronizeStoreAcrossProjection() async {
        let operation = Task { @MainActor in await store.synchronize(with: sessionAccess) }
        await operation.value
    }
}

private extension FollowedForumsState {
    var canReload: Bool {
        switch self {
        case .empty, .initialFailure, .loaded, .refreshFailure: true
        case .expired, .initialLoading, .refreshing, .signedOut, .signingIn: false
        }
    }
}

enum FollowedForumsAccessibilityID {
    static let empty = "followed-forums.state.empty"
    static let expired = "followed-forums.session.expired"
    static let failure = "followed-forums.state.failure"
    static let initialLoading = "followed-forums.state.initial-loading"
    static let list = "followed-forums.list"
    static let login = "followed-forums.session.login"
    static let reload = "followed-forums.reload"
    static let root = "app.root.followed-forums"
    static let signedOut = "followed-forums.session.signed-out"
    static let signingIn = "followed-forums.session.signing-in"

    static func row(_ forumID: Int64) -> String { "followed-forums.row.f\(forumID)" }
}
