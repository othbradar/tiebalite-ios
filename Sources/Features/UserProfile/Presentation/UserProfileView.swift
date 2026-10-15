import SwiftUI

@MainActor
struct UserProfileView: View {
    let imageLoader: any ImageLoading
    @Bindable var store: UserProfileStore
    let onDisplayed: (UserProfile) async -> Void
    var openList: (ProfileListRoute) -> Void = { _ in }
    var blocking: LocalBlockingStore?
    @State private var showsBlockedUsers = false

    var body: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                InitialLoadingView(title: "正在加载用户资料")
            case .failed:
                FullPageErrorView(
                    title: "用户资料加载失败",
                    message: "暂时无法获取该用户资料。",
                    retry: { Task { await store.retry() } }
                )
            case .empty:
                EmptyStateView(
                    title: "暂无用户资料",
                    message: "该用户暂时没有可显示的公开资料。",
                    systemImage: "info.circle"
                )
            case let .loaded(profile):
                profileContent(profile)
                    .task(id: profile.userID) {
                        await recordDisplayedUserAcrossProjection(profile)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle(store.route.fallbackDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(
            "user-profile.screen.\(store.route.userID.rawValue)"
        )
        .task(id: store.route.userID) {
            async let profile: Void = store.loadIfNeeded()
            async let detail: Void? = store.details?.activate()
            await blocking?.activate()
            _ = await (profile, detail)
        }
        .task(id: store.details?.activationScope) { await store.details?.activate() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            if let blocking {
                Menu {
                    if store.details?.isSelf != true {
                        Button(blocking.ids.contains(store.route.userID.rawValue) ? "取消本机屏蔽" : "本机屏蔽") {
                            Task { await blocking.set(.init(id: store.route.userID.rawValue, name: store.route.fallbackDisplayName),
                                                      blocked: !blocking.ids.contains(store.route.userID.rawValue)) }
                        }.accessibilityIdentifier("profile.block-toggle")
                    }
                    Button("本机屏蔽名单") { showsBlockedUsers = true }.accessibilityIdentifier("profile.block-management")
                } label: { Image(systemName: "ellipsis") }
                .accessibilityIdentifier("profile.more")
            }
        } }
        .sheet(isPresented: $showsBlockedUsers) {
            if let blocking { LocalBlockedUsersView(store: blocking) }
        }
    }

    private func recordDisplayedUserAcrossProjection(
        _ profile: UserProfile
    ) async {
        let operation = Task { @MainActor in
            guard store.claimDisplayedUser(profile.userID) else {
                return
            }
            await onDisplayed(profile)
        }
        await operation.value
    }

    private func profileContent(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProfileSummaryView(profile: profile, title: profile.displayName, subtitle: nil, imageLoader: imageLoader)
                ProfileStatisticsView(profile: profile)
                profileFacts(profile)
                if let details = store.details { profileActions(details) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TiebaParityTokens.horizontalInset)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier(
            "user-profile.loaded.\(profile.userID.rawValue)"
        )
    }

    private func profileActions(_ details: ProfileDetailsStore) -> some View {
        VStack(spacing: 0) {
            if blocking?.error == true {
                Text("本机屏蔽保存失败，请重试").font(.caption).foregroundStyle(SemanticColor.secondaryText)
            }
            if !details.isSelf {
                Button(details.relationship?.isFollowed == true ? "已关注" : "关注") {
                    Task { await details.toggleFollowing() }
                }
                .disabled(!details.canFollow || details.changingFollow)
                .frame(minHeight: 44).accessibilityIdentifier("profile.follow")
                if details.followFailed {
                    Text("关注操作失败，请重试").font(.caption).foregroundStyle(SemanticColor.secondaryText)
                } else if details.relationshipFailed {
                    Button("关系状态加载失败，重试") { Task { await details.activate() } }
                        .font(.caption).accessibilityIdentifier("profile.relationship-retry")
                }
            }
            ForEach(ProfileSection.allCases.filter { $0 != .replies || details.isSelf }, id: \.self) { section in
                Button { openList(.init(user: store.route, section: section)) } label: {
                    HStack { Text(section.title); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                        .foregroundStyle(SemanticColor.primaryText).frame(minHeight: 48).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("profile.open.\(section.rawValue)")
                TiebaFlatDivider()
            }
        }.font(.subheadline)
    }

    private func profileFacts(_ profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            TiebaFlatDivider()
            VStack(alignment: .leading, spacing: Spacing.small) {
                if let sex = profile.sex {
                    LabeledContent("性别", value: sex == .male ? "男" : "女")
                }
                if let count = profile.totalAgreeCount {
                    LabeledContent("获赞", value: "\(count)")
                }
                if let count = profile.threadCount {
                    LabeledContent("主题", value: "\(count)")
                }
            }
            .font(Typography.font(.body))
            .padding(.vertical, Spacing.medium)
        }
        .accessibilityIdentifier(
            "user-profile.facts.\(profile.userID.rawValue)"
        )
    }
}
