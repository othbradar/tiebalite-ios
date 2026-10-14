import SwiftUI

struct ExploreAppRootView: View {
    @Bindable var explore: ExploreStore
    let recommendations: RecommendationsStore
    let sessionStore: SessionStore
    let auth: SessionAuthContextProvider
    let policy: RecommendationsAccessPolicy
    let imageLoader: any ImageLoading
    let openLogin: () -> Void
    let openUser: (UserProfileRoute) -> Void
    let openThread: (RecommendationSummary, ExploreTab) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scope: ContentCacheContext {
        policy == .unrestrictedFixture ? .init(namespace: "fixture", revision: 0) : auth.contentCacheContext
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                ForEach(ExploreTab.allCases, id: \.self) { tab in
                    Button { explore.select(tab) } label: {
                        VStack(spacing: 4) {
                            Text(tab.title).font(.subheadline.bold())
                                .foregroundStyle(explore.selected == tab ? SemanticColor.primaryText : SemanticColor.secondaryText)
                            Capsule().fill(explore.selected == tab ? SemanticColor.primaryText : .clear).frame(width: 20, height: 3)
                        }.frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("explore.tab.\(tab.rawValue)")
                    .accessibilityAddTraits(explore.selected == tab ? .isSelected : [])
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, TiebaParityTokens.horizontalInset)
            TiebaFlatDivider(inset: 0)
            PagerContainer(pageIDs: ExploreTab.allCases, selection: $explore.selected,
                           backgroundColor: .systemBackground, reduceMotion: reduceMotion,
                           externalSelectionGeneration: $explore.selectionGeneration,
                           retainedPageIDs: Set(ExploreTab.allCases), contentGeneration: { _ in 0 }, content: { tab in
                PageHost(root: self, tab: tab)
            })
            .accessibilityIdentifier("explore.pager")
        }
        .background(SemanticColor.background)
        .navigationTitle("动态").navigationBarTitleDisplayMode(.inline)
        .task(id: Activation(tab: explore.selected, scope: scope)) {
            if explore.following.scope != scope { explore.following.reset(scope: scope) }
            if explore.hot.scope != scope { explore.hot.reset(scope: scope) }
            switch explore.selected {
            case .following: await explore.following.activate(scope: scope)
            case .hot: await explore.hot.activate(scope: scope)
            case .recommendations: explore.recommendationsVisited = true
            case nil: break
            }
        }
        .onChange(of: explore.selected) { old, _ in
            if old == .following { explore.following.deactivate() }
            if old == .hot { explore.hot.deactivate() }
        }
        .onDisappear { explore.following.deactivate(); explore.hot.deactivate() }
    }

    @ViewBuilder private func page(_ tab: ExploreTab) -> some View {
        switch tab {
        case .recommendations:
            if explore.recommendationsVisited {
                RecommendationsAppRootView(store: recommendations, sessionStore: sessionStore,
                                           authContextProvider: auth, accessPolicy: policy, imageLoader: imageLoader,
                                           openLogin: openLogin, onOpenUser: openUser,
                                           onOpenThread: { openThread($0, .recommendations) })
            } else { SemanticColor.background }
        case .following, .hot:
            let store = tab == .following ? explore.following : explore.hot
            if store.scope == scope {
                ExploreFeedView(store: store, imageLoader: imageLoader, openLogin: openLogin,
                                openThread: { openThread($0, tab) }, openUser: openUser)
            } else { SemanticColor.background }
        }
    }

    private struct PageHost: View {
        let root: ExploreAppRootView
        let tab: ExploreTab
        var body: some View { root.page(tab) }
    }

    private struct Activation: Hashable {
        let tab: ExploreTab?
        let scope: ContentCacheContext
    }
}
