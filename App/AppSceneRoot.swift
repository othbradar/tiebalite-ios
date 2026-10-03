import SwiftUI

@MainActor
struct AppSceneRoot: View {
    @Environment(\.scenePhase) private var scenePhase
    private let compositionRoot: AppCompositionRoot
    private let harnessLabel: String?

    @State private var navigationStore: AppNavigationStore
    @State private var featureStores: AppFeatureStoreRegistry
    @State private var mediaPresentation: MediaViewerPresentation?
    @State private var sessionStore: SessionStore
    @State private var isLoginPresented = false

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
        _sessionStore = State(initialValue: compositionRoot.sessionStore)
    }

    var body: some View {
        Group {
            if sessionStore.isLaunchRestoreResolved,
               featureStores.settingsStore.isLoaded {
                AppShellView(
                    navigation: navigationStore,
                    harnessLabel: harnessLabel,
                    environment: compositionRoot.environment,
                    featureStores: featureStores,
                    sessionStore: sessionStore,
                    authContextProvider: compositionRoot.authContextProvider,
                    notificationCounts: compositionRoot.notificationCounts,
                    onOpenLogin: openLogin,
                    onOpenMedia: presentMedia
                )
            } else {
                InitialLoadingView(title: "正在恢复会话")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SemanticColor.background)
            }
        }
        .environment(\.textComposer, compositionRoot.textComposer)
        .modifier(TextComposerHost(service: compositionRoot.textComposer))
        .fullScreenCover(item: $mediaPresentation) { presentation in
            MediaViewer(
                presentation: presentation,
                imageLoader: compositionRoot.environment.imageLoader,
                exportStore: compositionRoot.makeMediaExportStore(),
                close: {
                    mediaPresentation = nil
                }
            )
        }
        .sheet(
            isPresented: $isLoginPresented,
            onDismiss: finishLoginDismissal
        ) {
            LoginView(
                store: sessionStore,
                webSession: compositionRoot.loginWebSession,
                cancel: {
                    isLoginPresented = false
                },
                completed: {
                    isLoginPresented = false
                }
            )
        }
        .task {
            compositionRoot.contentPrefetchEnvironment.setActive(scenePhase == .active)
            await sessionStore.restoreIfNeeded()
            await updateNotifications()
        }
        .onChange(of: sessionStore.state) { _, _ in
            compositionRoot.contentPrefetchEnvironment.cancelAll()
            compositionRoot.currentAccountStore.updateContext(compositionRoot.authContextProvider.context())
            compositionRoot.notificationsStore.updateContext(compositionRoot.authContextProvider.context())
            Task { await compositionRoot.notificationsStore.refreshCounts() }
        }
        .onChange(of: scenePhase) { _, phase in
            compositionRoot.contentPrefetchEnvironment.setActive(phase == .active)
            if phase == .active { Task { await updateNotifications() } }
        }
        .task {
            await featureStores.settingsStore.loadIfNeeded()
        }
        .onChange(of: featureStores.settingsStore.settings) { _, _ in
            compositionRoot.contentPrefetchEnvironment.cancelAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            compositionRoot.contentPrefetchEnvironment.policyChanged()
        }
        .preferredColorScheme(
            featureStores.settingsStore.appearance.colorScheme
        )
        .onOpenURL { url in
            navigationStore.handleExternalURL(url)
        }
        .onChange(of: navigationStore.state) { _, newState in
            featureStores.retainFeatureStores(in: newState)
        }
    }

    private func updateNotifications() async {
        compositionRoot.notificationsStore.updateContext(compositionRoot.authContextProvider.context())
        await compositionRoot.notificationsStore.refreshCounts()
    }

    private func presentMedia(_ intent: ThreadMediaIntent) {
        guard let presentation = MediaViewerPresentation(intent: intent) else {
            return
        }
        mediaPresentation = presentation
    }

    private func openLogin() {
        guard sessionStore.state != .signedIn,
              !sessionStore.isBusy else {
            return
        }
        compositionRoot.loginWebSession.prepareForLogin()
        sessionStore.beginSignIn()
        isLoginPresented = true
    }

    private func finishLoginDismissal() {
        guard sessionStore.state != .signedIn else {
            return
        }
        Task {
            await sessionStore.cancelSignIn()
        }
    }
}
