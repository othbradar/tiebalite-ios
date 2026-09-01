import SwiftUI

@MainActor
struct RecommendationsAppRootView: View {
    @Bindable var store: RecommendationsStore
    @Bindable var sessionStore: SessionStore
    let authContextProvider: SessionAuthContextProvider
    let accessPolicy: RecommendationsAccessPolicy
    let imageLoader: any ImageLoading
    let openLogin: () -> Void
    let onOpenThread: (RecommendationSummary) -> Void

    @State private var synchronizedScope: RecommendationsAccessScope?

    @ViewBuilder
    var body: some View {
        Group {
            if accessPolicy == .unrestrictedFixture {
                synchronizedRecommendations
            } else {
                liveContent
            }
        }
        .task(id: accessScope) {
            let requestedScope = accessScope
            let operation = Task { @MainActor in
                await store.synchronize(with: requestedScope)
            }
            await operation.value
            guard !Task.isCancelled,
                  accessScope == requestedScope else {
                return
            }
            synchronizedScope = requestedScope
        }
    }

    @ViewBuilder
    private var liveContent: some View {
        switch sessionStore.state {
        case .signedIn:
            if case .active = accessScope {
                synchronizedRecommendations
            } else {
                sessionPrompt(
                    title: "登录后查看推荐",
                    message: "当前会话不完整，请重新登录后加载推荐。",
                    buttonTitle: "登录",
                    stateIdentifier:
                        RecommendationsAccessibilityID.sessionSignedOut
                )
            }
        case .signingIn:
            InitialLoadingView(title: "正在登录")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SemanticColor.background)
                .navigationTitle("推荐")
                .accessibilityIdentifier(
                    RecommendationsAccessibilityID.sessionSigningIn
                )
        case .expired:
            sessionPrompt(
                title: "登录已失效",
                message: "请重新登录后再加载推荐。",
                buttonTitle: "重新登录",
                stateIdentifier: RecommendationsAccessibilityID.sessionExpired
            )
        case .failed, .signedOut, .signingOut:
            sessionPrompt(
                title: "登录后查看推荐",
                message: "使用现有网页登录即可加载个性化推荐。",
                buttonTitle: "登录",
                stateIdentifier:
                    RecommendationsAccessibilityID.sessionSignedOut
            )
        }
    }

    @ViewBuilder
    private var synchronizedRecommendations: some View {
        if synchronizedScope == accessScope {
            recommendations
        } else {
            InitialLoadingView(title: "正在加载推荐")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SemanticColor.background)
                .navigationTitle("推荐")
                .accessibilityIdentifier(
                    RecommendationsAccessibilityID.initialLoading
                )
        }
    }

    private var accessScope: RecommendationsAccessScope {
        guard accessPolicy == .activeSessionRequired else {
            return .fixture
        }
        guard sessionStore.state == .signedIn,
              case let .active(lease) = authContextProvider.context() else {
            return .unavailable
        }
        return .active(lease)
    }

    private var recommendations: some View {
        RecommendationsView(
            store: store,
            imageLoader: imageLoader,
            onOpenThread: onOpenThread
        )
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
                .accessibilityIdentifier(
                    RecommendationsAccessibilityID.sessionLogin
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.large)
        .background(SemanticColor.background)
        .navigationTitle("推荐")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(RecommendationsAccessibilityID.root)
    }
}
