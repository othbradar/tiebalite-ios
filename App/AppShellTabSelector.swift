import SwiftUI

@MainActor
struct PhoneTabSelector: View {
    @Bindable var navigation: AppNavigationStore
    let notificationCounts: any NotificationCountSource

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(SemanticColor.separator)
                .frame(height: 1)
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    Button { navigation.selectTab(tab) } label: {
                        RootTabIcon(
                            tab: tab,
                            selected: navigation.state.selectedTab == tab,
                            unreadCount: tab == .notifications ? notificationCounts.unreadCount : 0
                        )
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityValue(accessibilityValue(for: tab))
                    .selectedAccessibilityTrait(navigation.state.selectedTab == tab)
                    .accessibilityIdentifier(tab.accessibilityIdentifier)
                }
            }
        }
        .background {
            SemanticColor.background.ignoresSafeArea(edges: .bottom)
        }
    }

    private func accessibilityValue(for tab: AppTab) -> String {
        let selected = navigation.state.selectedTab == tab ? "已选择" : ""
        guard tab == .notifications, notificationCounts.unreadCount > 0 else { return selected }
        return [selected, "\(notificationCounts.unreadCount) 条未读消息"]
            .filter { !$0.isEmpty }.joined(separator: "，")
    }
}

@MainActor
struct AppSidebarItem: View {
    let tab: AppTab
    @Bindable var navigation: AppNavigationStore
    let notificationCounts: any NotificationCountSource

    var body: some View {
        Button { navigation.selectTab(tab) } label: {
            HStack(spacing: Spacing.medium) {
                RootTabIcon(
                    tab: tab,
                    selected: navigation.state.selectedTab == tab,
                    unreadCount: tab == .notifications ? notificationCounts.unreadCount : 0
                )
                Text(tab.title)
                    .foregroundStyle(SemanticColor.primaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityValue(
            tab == .notifications && notificationCounts.unreadCount > 0
                ? "\(notificationCounts.unreadCount) 条未读消息" : ""
        )
        .selectedAccessibilityTrait(navigation.state.selectedTab == tab)
        .accessibilityIdentifier(tab.accessibilityIdentifier)
        .listRowBackground(
            navigation.state.selectedTab == tab ? SemanticColor.surface : Color.clear
        )
    }
}

private struct RootTabIcon: View {
    let tab: AppTab
    let selected: Bool
    let unreadCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(tab.iconAssetName + (selected ? "-selected" : ""))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(
                    selected ? SemanticColor.primaryText : SemanticColor.secondaryText.opacity(0.5)
                )
            if let text = NotificationBadgePresentation.text(for: unreadCount) {
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SemanticColor.background)
                    .padding(.horizontal, 3)
                    .frame(minWidth: 14, minHeight: 14)
                    .background(SemanticColor.primaryText, in: Capsule())
                    .offset(x: 7, y: -5)
            }
        }
        // Purely visual badge shares its button's label and hit area.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    @ViewBuilder
    func selectedAccessibilityTrait(_ isSelected: Bool) -> some View {
        if isSelected {
            accessibilityAddTraits(.isSelected)
        } else {
            self
        }
    }
}
