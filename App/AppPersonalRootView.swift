import SwiftUI

@MainActor
struct AppPersonalRootView: View {
    @Bindable var accountStore: CurrentAccountStore
    @Bindable var settingsStore: SettingsStore
    let imageLoader: any ImageLoading
    let authContextProvider: SessionAuthContextProvider
    @Bindable var sessionStore: SessionStore
    let openLogin: () -> Void
    let openRoute: (SettingsRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                accountHeader
                if let profile = accountStore.profile { ProfileStatisticsView(profile: profile) }
                if accountStore.failed {
                    Button("资料加载失败，轻点重试") { Task { await accountStore.refresh() } }
                        .font(.caption).foregroundStyle(SemanticColor.secondaryText)
                        .frame(minHeight: 44).accessibilityIdentifier("personal.account.retry")
                }
                entry("浏览记录", symbol: "clock", identifier: "settings.open-history") { openRoute(.history) }
                themeSelection
                TiebaFlatDivider().padding(.vertical, 8)
                entry("设置", symbol: "gearshape", identifier: AppAccessibilityID.personalSettings) { openRoute(.preferences) }
                entry("关于", symbol: "info.circle", identifier: "settings.open-about") { openRoute(.about) }
                TiebaFlatDivider().padding(.vertical, 8)
                SessionAccountView(store: sessionStore, openLogin: openLogin)
            }
            .padding(.horizontal, TiebaParityTokens.horizontalInset)
            .padding(.bottom, 16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(SemanticColor.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AppAccessibilityID.personalRoot)
        .refreshable { await accountStore.refresh() }
        .task(id: sessionStore.state) {
            accountStore.updateContext(authContextProvider.context())
            await accountStore.loadIfNeeded()
        }
    }

    private var accountHeader: some View {
        Button {
            if accountStore.profile != nil {
                openRoute(.accountProfile)
            } else if sessionStore.state == .signedIn {
                Task { await accountStore.refresh() }
            } else {
                openLogin()
            }
        } label: {
            ProfileSummaryView(profile: accountStore.profile,
                               title: sessionStore.state == .signedIn ? "当前账户" : "登录贴吧",
                               subtitle: accountStore.isLoading ? "正在加载资料" : nil,
                               imageLoader: imageLoader)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AppAccessibilityID.personalProfile)
    }

    private var themeSelection: some View {
        Menu {
            Picker("主题选择", selection: Binding(get: { settingsStore.appearance }, set: { settingsStore.setAppearance($0) })) {
                ForEach(AppAppearancePreference.allCases, id: \.self) { preference in
                    Text(preference.title).tag(preference)
                }
            }
        } label: {
            HStack(spacing: 16) {
                menuLabel("主题选择", symbol: "paintbrush")
                Text(settingsStore.appearance.title).font(.caption).foregroundStyle(SemanticColor.secondaryText)
            }
            .padding(.vertical, 12).frame(minHeight: 52).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("personal.theme")
    }

    private func entry(_ title: String, symbol: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            menuLabel(title, symbol: symbol).padding(.vertical, 12).frame(minHeight: 52).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(identifier)
    }

    private func menuLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.title3).frame(width: 28).accessibilityHidden(true)
            Text(title).font(.body.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(SemanticColor.primaryText)
    }
}
