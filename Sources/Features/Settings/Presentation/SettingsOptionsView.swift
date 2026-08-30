import SwiftUI

@MainActor
struct SettingsOptionsView: View {
    @Bindable var store: SettingsStore
    @Bindable var historyStore: BrowsingHistoryStore
    let openHistory: () -> Void
    let openAbout: () -> Void
    let runtimeModeDescription: String?

    @State private var confirmsHistoryClear = false

    var body: some View {
        VStack(spacing: Spacing.medium) {
            settingsGroup(title: "外观") {
                Picker("外观", selection: appearanceBinding) {
                    ForEach(AppAppearancePreference.allCases, id: \.self) {
                        Text($0.title).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.appearance")
            }

            settingsGroup(title: "阅读") {
                Picker("正文文字大小", selection: readingSizeBinding) {
                    ForEach(ReadingTextSizePreference.allCases, id: \.self) {
                        Text($0.title).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.reading-text-size")
            }

            settingsGroup(title: "历史与隐私") {
                settingsButton(
                    title: "浏览历史",
                    value: "\(historyStore.count) 条",
                    systemImage: "clock",
                    accessibilityIdentifier: "settings.open-history",
                    action: openHistory
                )
                settingsButton(
                    title: "清空浏览历史",
                    value: nil,
                    systemImage: "trash",
                    role: .destructive,
                    accessibilityIdentifier: "settings.clear-history",
                    action: { confirmsHistoryClear = true }
                )
                .disabled(!historyStore.canClearHistory)
                if historyStore.hasPersistenceFailure {
                    Text("部分浏览历史未能保存，可清空后重试。")
                        .font(Typography.font(.caption))
                        .foregroundStyle(SemanticColor.error)
                        .accessibilityIdentifier(
                            "settings.history-persistence-warning"
                        )
                }
            }

            settingsGroup(title: "关于") {
                settingsButton(
                    title: "TiebaLite",
                    value: AppVersionInfo.displayVersion,
                    systemImage: "info.circle",
                    accessibilityIdentifier: "settings.open-about",
                    action: openAbout
                )
#if DEBUG
                if let runtimeModeDescription {
                    LabeledContent("数据模式", value: runtimeModeDescription)
                        .font(Typography.font(.body))
                        .accessibilityIdentifier("settings.debug.runtime-mode")
                }
#endif
            }
        }
        .task {
            await historyStore.loadIfNeeded()
        }
        .alert("清空浏览历史？", isPresented: $confirmsHistoryClear) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                Task { await historyStore.clear() }
            }
        } message: {
            Text("这只会删除本 App 保存的浏览记录。")
        }
    }

    private var appearanceBinding: Binding<AppAppearancePreference> {
        Binding(
            get: { store.appearance },
            set: { value in store.setAppearance(value) }
        )
    }

    private var readingSizeBinding: Binding<ReadingTextSizePreference> {
        Binding(
            get: { store.readingTextSize },
            set: { value in store.setReadingTextSize(value) }
        )
    }

    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .font(Typography.font(.headline))
                .foregroundStyle(SemanticColor.primaryText)
            VStack(spacing: Spacing.small) {
                content()
            }
            .padding(Spacing.medium)
            .background(SemanticColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsButton(
        title: String,
        value: String?,
        systemImage: String,
        role: ButtonRole? = nil,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: Spacing.small) {
                Label(title, systemImage: systemImage)
                Spacer(minLength: Spacing.small)
                if let value {
                    Text(value)
                        .foregroundStyle(SemanticColor.secondaryText)
                }
                Image(systemName: "chevron.right")
                    .font(Typography.font(.caption))
                    .foregroundStyle(SemanticColor.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

enum AppVersionInfo {
    static var displayVersion: String {
        let bundle = Bundle.main
        let version = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.1.0"
        let build = bundle.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "1"
        return "\(version) (\(build))"
    }
}
