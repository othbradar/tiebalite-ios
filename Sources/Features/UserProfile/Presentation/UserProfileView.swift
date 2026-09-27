import SwiftUI

@MainActor
struct UserProfileView: View {
    let imageLoader: any ImageLoading
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
            VStack(alignment: .leading, spacing: 0) {
                ProfileSummaryView(profile: profile, title: profile.displayName, subtitle: nil, imageLoader: imageLoader)
                ProfileStatisticsView(profile: profile)
                profileFacts(profile)
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

    private func profileFacts(_ profile: UserProfile) -> some View {
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
        .overlay(alignment: .top) { TiebaFlatDivider() }
        .accessibilityIdentifier(
            "user-profile.facts.\(profile.userID.rawValue)"
        )
    }
}
