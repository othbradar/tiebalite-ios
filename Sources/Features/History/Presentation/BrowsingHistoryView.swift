import SwiftUI

@MainActor
struct BrowsingHistoryView: View {
    @Bindable var store: BrowsingHistoryStore
    let openRoute: (RouteIdentity) -> Void

    @State private var confirmsClear = false

    var body: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                InitialLoadingView(title: "正在读取浏览历史")
            case .failed:
                FullPageErrorView(
                    title: "历史记录读取失败",
                    message: "本机历史暂时无法读取。",
                    retry: { Task { await store.reload() } }
                )
            case let .loaded(entries):
                historyList(entries)
            }
        }
        .background(SemanticColor.background)
        .navigationTitle("浏览历史")
        .accessibilityIdentifier("history.screen")
        .toolbar {
            if store.canClearHistory {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空") {
                        confirmsClear = true
                    }
                    .accessibilityIdentifier("history.clear")
                }
            }
        }
        .alert("清空浏览历史？", isPresented: $confirmsClear) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                Task { await store.clear() }
            }
        } message: {
            Text("这只会删除本 App 保存的浏览记录。")
        }
        .task {
            await store.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func historyList(
        _ entries: [BrowsingHistoryEntry]
    ) -> some View {
        if entries.isEmpty {
            VStack(spacing: Spacing.medium) {
                if store.hasPersistenceFailure {
                    persistenceWarning
                        .padding(.horizontal, Spacing.large)
                }
                EmptyStateView(
                    title: "暂无浏览历史",
                    message: "成功打开贴子、贴吧或用户资料后会记录在这里。",
                    systemImage: "clock"
                )
            }
        } else {
            List {
                if store.hasPersistenceFailure {
                    persistenceWarning
                    .listRowBackground(SemanticColor.surface)
                }
                ForEach(entries) { entry in
                    Button {
                        openRoute(entry.route)
                    } label: {
                        HStack(spacing: Spacing.medium) {
                            Image(systemName: entry.systemImage)
                                .foregroundStyle(SemanticColor.accent)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                Text(entry.title)
                                    .font(Typography.font(.headline))
                                    .foregroundStyle(SemanticColor.primaryText)
                                if let subtitle = entry.subtitle {
                                    Text(subtitle)
                                        .font(Typography.font(.caption))
                                        .foregroundStyle(
                                            SemanticColor.secondaryText
                                        )
                                }
                            }
                            Spacer(minLength: Spacing.small)
                            Text(entry.visitedAt, style: .relative)
                                .font(Typography.font(.caption))
                                .foregroundStyle(SemanticColor.secondaryText)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(entry.accessibilityIdentifier)
                    .swipeActions {
                        Button("删除", role: .destructive) {
                            Task { await store.delete(entry.identity) }
                        }
                    }
                    .listRowBackground(SemanticColor.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(SemanticColor.background)
            .accessibilityIdentifier("history.list")
        }
    }

    private var persistenceWarning: some View {
        Label(
            "部分浏览历史未能保存，可清空后重试。",
            systemImage: "exclamationmark.triangle"
        )
        .font(Typography.font(.subheadline))
        .foregroundStyle(SemanticColor.error)
        .accessibilityIdentifier("history.persistence-warning")
    }
}

private extension BrowsingHistoryEntry {
    var systemImage: String {
        switch identity {
        case .forum:
            "rectangle.stack"
        case .thread:
            "doc.text"
        case .user:
            "person.crop.circle"
        }
    }

    var accessibilityIdentifier: String {
        switch identity {
        case let .forum(rawID):
            "history.row.forum.\(rawID)"
        case let .thread(rawID):
            "history.row.thread.\(rawID)"
        case let .user(rawID):
            "history.row.user.\(rawID)"
        }
    }
}
