import SwiftUI

@MainActor
struct AppPersonalRootView: View {
    @Bindable var sessionStore: SessionStore
    let openLogin: () -> Void
    let openRoute: (SettingsRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                entry(
                    sessionStore.state == .signedIn ? "个人资料" : "登录后查看个人资料",
                    symbol: "person.crop.rectangle",
                    identifier: AppAccessibilityID.personalProfile
                ) {
                    if sessionStore.state == .signedIn {
                        openRoute(.accountProfile)
                    } else {
                        openLogin()
                    }
                }
                entry("浏览历史", symbol: "clock", identifier: "settings.open-history") {
                    openRoute(.history)
                }
                TiebaFlatDivider(inset: 0)
                    .padding(.vertical, Spacing.small)
                entry("设置", symbol: "gearshape", identifier: AppAccessibilityID.personalSettings) {
                    openRoute(.preferences)
                }
                entry("关于", symbol: "info.circle", identifier: "settings.open-about") {
                    openRoute(.about)
                }
#if DEBUG
                TiebaFlatDivider(inset: 0)
                    .padding(.vertical, Spacing.small)
                DebugScenarioMenuView(
                    openGallery: { openRoute(.componentGallery) },
                    openInteractionLab: { openRoute(.interactionLab) },
                    openThreadContentRenderer: { openRoute(.threadContentRendererLab) }
                )
#endif
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.top, Spacing.small)
        }
        .background(SemanticColor.background)
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AppAccessibilityID.personalRoot)
    }

    private func entry(
        _ title: String,
        symbol: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typography.font(.body))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(SemanticColor.primaryText)
            .padding(.vertical, Spacing.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

struct NotificationsRootView: View {
    var body: some View {
        VStack(spacing: Spacing.small) {
            Text("消息待实现")
                .font(Typography.font(.headline))
            Text("回复我的、提到我的将在后续版本提供。")
                .font(Typography.font(.body))
                .foregroundStyle(SemanticColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle("消息")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppAccessibilityID.notificationsRoot)
    }
}
