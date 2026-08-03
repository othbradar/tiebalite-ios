import SwiftUI

@MainActor
struct AppSceneRoot: View {
    private let compositionRoot: AppCompositionRoot
    private let harnessLabel: String?

    @State private var navigationStore: AppNavigationStore
    @State private var featureStores: AppFeatureStoreRegistry
    @State private var mediaPresentation: MediaViewerPresentation?

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
        _featureStores = State(
            initialValue: AppFeatureStoreRegistry(
                compositionRoot: compositionRoot
            )
        )
        _mediaPresentation = State(initialValue: nil)
    }

    var body: some View {
        AppShellView(
            navigation: navigationStore,
            harnessLabel: harnessLabel,
            environment: compositionRoot.environment,
            featureStores: featureStores,
            onOpenMedia: presentMedia
        )
        .fullScreenCover(item: $mediaPresentation) { presentation in
            MediaViewer(
                presentation: presentation,
                imageLoader: compositionRoot.environment.imageLoader,
                close: {
                    mediaPresentation = nil
                }
            )
        }
        .onOpenURL { url in
            navigationStore.handleExternalURL(url)
        }
        .onChange(of: navigationStore.state) { _, newState in
            featureStores.retainThreadStores(in: newState)
        }
    }

    private func presentMedia(_ intent: ThreadMediaIntent) {
        guard let presentation = MediaViewerPresentation(intent: intent) else {
            return
        }
        mediaPresentation = presentation
    }
}
