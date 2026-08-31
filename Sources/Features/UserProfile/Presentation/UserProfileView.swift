import SwiftUI

@MainActor
struct UserProfileView: View {
    @Bindable var store: UserProfileStore
    let onDisplayed: (UserProfile) async -> Void

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
                    systemImage: "person.crop.circle.badge.questionmark"
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
            await store.loadIfNeeded()
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
            VStack(alignment: .leading, spacing: Spacing.large) {
                HStack(spacing: Spacing.medium) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(SemanticColor.secondaryText)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text(profile.displayName)
                            .font(Typography.font(.title))
                            .foregroundStyle(SemanticColor.primaryText)
                            .accessibilityAddTraits(.isHeader)
                    }
                }

                if let introduction = profile.introduction {
                    Text(introduction)
                        .font(Typography.font(.body))
                        .foregroundStyle(SemanticColor.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                profileFacts(profile)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.large)
        }
        .accessibilityIdentifier(
            "user-profile.loaded.\(profile.userID.rawValue)"
        )
    }

    private func profileFacts(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let sex = profile.sex {
                LabeledContent("性别", value: sex == .male ? "男" : "女")
            }
            if let count = profile.followingCount {
                LabeledContent("关注", value: "\(count)")
            }
            if let count = profile.followerCount {
                LabeledContent("粉丝", value: "\(count)")
            }
            if let count = profile.totalAgreeCount {
                LabeledContent("获赞", value: "\(count)")
            }
            if let count = profile.threadCount {
                LabeledContent("主题", value: "\(count)")
            }
            if let count = profile.postCount {
                LabeledContent("发言", value: "\(count)")
            }
        }
        .font(Typography.font(.body))
        .padding(Spacing.medium)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityIdentifier(
            "user-profile.facts.\(profile.userID.rawValue)"
        )
    }
}
