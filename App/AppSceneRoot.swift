import SwiftUI

@MainActor
struct AppSceneRoot: View {
    private let compositionRoot: AppCompositionRoot
    private let harnessLabel: String?

    @State private var navigationStore: AppNavigationStore

    init(
        compositionRoot: AppCompositionRoot,
        harnessLabel: String? = nil,
        initialNavigationState: AppNavigationState = AppNavigationState()
    ) {
        self.compositionRoot = compositionRoot
        self.harnessLabel = harnessLabel
        _navigationStore = State(
            initialValue: AppNavigationStore(
                initialState: initialNavigationState
            )
        )
    }

    var body: some View {
        AppShellView(
            navigation: navigationStore,
            harnessLabel: harnessLabel,
            environment: compositionRoot.environment
        )
        .onOpenURL { url in
            navigationStore.handleExternalURL(url)
        }
    }
}
