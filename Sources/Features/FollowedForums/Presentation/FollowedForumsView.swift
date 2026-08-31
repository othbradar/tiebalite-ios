import SwiftUI

@MainActor
struct FollowedForumsView: View {
    @Bindable var store: FollowedForumsStore
    let sessionAccess: FollowedForumsSessionAccess
    let openLogin: () -> Void
    let openForum: (FollowedForum) -> Void

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SemanticColor.background)
            .navigationTitle("关注的吧")
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(FollowedForumsAccessibilityID.root)
            .task(id: sessionAccess) {
                await synchronizeStoreAcrossProjection()
            }
            .toolbar {
                if store.state.canReload {
                    Button("重新加载", systemImage: "arrow.clockwise") {
                        Task {
                            await store.reload()
                        }
                    }
                    .accessibilityIdentifier(
                        FollowedForumsAccessibilityID.reload
                    )
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .signedOut:
            sessionPrompt(
                title: "登录后查看关注的吧",
                message: "使用现有网页登录即可读取你的关注列表。",
                buttonTitle: "登录",
                stateIdentifier: FollowedForumsAccessibilityID.signedOut
            )
        case .signingIn:
            InitialLoadingView(title: "正在登录")
                .accessibilityIdentifier(
                    FollowedForumsAccessibilityID.signingIn
                )
        case .expired:
            sessionPrompt(
                title: "登录已失效",
                message: "请重新登录后再加载关注列表。",
                buttonTitle: "重新登录",
                stateIdentifier: FollowedForumsAccessibilityID.expired
            )
        case .initialLoading:
            InitialLoadingView(title: "正在加载关注的吧")
                .accessibilityIdentifier(
                    FollowedForumsAccessibilityID.initialLoading
                )
        case .empty:
            EmptyStateView(
                title: "暂未关注贴吧",
                message: "当前账号没有可显示的关注吧。",
                systemImage: "star"
            )
            .accessibilityIdentifier(FollowedForumsAccessibilityID.empty)
        case .initialFailure:
            FullPageErrorView(
                title: "关注列表加载失败",
                message: "网络或服务暂时不可用。",
                retry: requestReload
            )
            .accessibilityIdentifier(FollowedForumsAccessibilityID.failure)
        case let .loaded(forums):
            forumList(forums)
        case let .refreshing(forums):
            forumList(forums, status: .loading)
        case let .refreshFailure(forums, _):
            forumList(forums, status: .failure)
        }
    }

    private func sessionPrompt(
        title: String,
        message: String,
        buttonTitle: String,
        stateIdentifier: String
    ) -> some View {
        VStack(spacing: Spacing.large) {
            EmptyStateView(
                title: title,
                message: message,
                systemImage: "person.crop.circle.badge.exclamationmark"
            )
            .accessibilityIdentifier(stateIdentifier)
            Button(buttonTitle, action: openLogin)
                .buttonStyle(.borderedProminent)
                .tint(SemanticColor.accent)
                .accessibilityIdentifier(FollowedForumsAccessibilityID.login)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.large)
        .background(SemanticColor.background)
    }

    private func forumList(
        _ forums: [FollowedForum],
        status: RetainedStatus? = nil
    ) -> some View {
        ScrollView {
            LazyVStack(spacing: Spacing.medium) {
                if status == .loading {
                    InlineLoadingView(title: "正在重新加载")
                } else if status == .failure {
                    InlineErrorView(
                        message: "重新加载失败，已保留原列表。",
                        retry: requestReload
                    )
                }

                ForEach(forums) { forum in
                    Button {
                        openForum(forum)
                    } label: {
                        FollowedForumRow(forum: forum)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("打开吧首页")
                    .accessibilityIdentifier(
                        FollowedForumsAccessibilityID.row(forum.forumID)
                    )
                    .id(forum.forumID)
                }
            }
            .scrollTargetLayout()
            .padding(Spacing.medium)
        }
        .scrollPosition(id: scrollAnchorBinding, anchor: .center)
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
    }

    private var scrollAnchorBinding: Binding<Int64?> {
        Binding(
            get: { store.scrollAnchor },
            set: { store.setScrollAnchor($0) }
        )
    }

    private func requestReload() {
        Task {
            await store.reload()
        }
    }

    private func synchronizeStoreAcrossProjection() async {
        let operation = Task { @MainActor in
            await store.synchronize(with: sessionAccess)
        }
        await operation.value
    }
}

@MainActor
private struct FollowedForumRow: View {
    let forum: FollowedForum

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: IconSize.large))
                .foregroundStyle(SemanticColor.accent)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(forum.name)
                    .font(Typography.font(.headline))
                    .foregroundStyle(SemanticColor.primaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.small) {
                        levelLabel
                        memberLabel
                    }
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        levelLabel
                        memberLabel
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(Typography.font(.caption))
                .foregroundStyle(SemanticColor.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var levelLabel: some View {
        if let levelID = forum.levelID {
            Label(
                forum.levelName ?? "等级 \(levelID)",
                systemImage: "chart.bar.fill"
            )
            .font(Typography.font(.caption))
            .foregroundStyle(SemanticColor.secondaryText)
        }
    }

    private var memberLabel: some View {
        Label("\(forum.memberCount) 位成员", systemImage: "person.2")
            .font(Typography.font(.caption))
            .foregroundStyle(SemanticColor.secondaryText)
    }
}

private enum RetainedStatus {
    case failure
    case loading
}

private extension FollowedForumsState {
    var canReload: Bool {
        switch self {
        case .empty, .initialFailure, .loaded, .refreshFailure:
            true
        case .expired, .initialLoading, .refreshing, .signedOut, .signingIn:
            false
        }
    }
}

enum FollowedForumsAccessibilityID {
    static let empty = "followed-forums.state.empty"
    static let expired = "followed-forums.session.expired"
    static let failure = "followed-forums.state.failure"
    static let initialLoading = "followed-forums.state.initial-loading"
    static let login = "followed-forums.session.login"
    static let reload = "followed-forums.reload"
    static let root = "app.root.followed-forums"
    static let signedOut = "followed-forums.session.signed-out"
    static let signingIn = "followed-forums.session.signing-in"

    static func row(_ forumID: Int64) -> String {
        "followed-forums.row.f\(forumID)"
    }
}
