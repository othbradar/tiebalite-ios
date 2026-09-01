import SwiftUI

struct AboutView: View {
    let openLicenses: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                EmptyStateView(
                    title: "TiebaLite",
                    message: "版本 \(AppVersionInfo.displayVersion)",
                    systemImage: "app"
                )
                Button("查看许可与来源", systemImage: "doc.text") {
                    openLicenses()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("settings.open-licenses")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.large)
        }
        .background(SemanticColor.background)
        .navigationTitle("关于")
        .accessibilityIdentifier("settings.about")
    }
}

struct OpenSourceLicensesView: View {
    var body: some View {
        List {
            Section("Swift Protobuf") {
                Text("版本 1.38.1")
                Text("Apache License 2.0 + Runtime Library Exception")
            }
            Section("本项目") {
                Text("本地 Beta RC；公开、App Store 与商业分发权利尚未确认。")
            }
            Section("参考项目") {
                Text("TiebaLite Android reference")
                Text("来源与许可记录见仓库 Docs/Audits/SOURCE_AND_LICENSE_NOTES.md。")
                    .font(Typography.font(.caption))
            }
        }
        .scrollContentBackground(.hidden)
        .background(SemanticColor.background)
        .navigationTitle("许可与来源")
        .accessibilityIdentifier("settings.licenses")
    }
}
