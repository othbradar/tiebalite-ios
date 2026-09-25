import SwiftUI

struct NotificationsView: View {
    @Bindable var store: NotificationsStore
    let imageLoader: any ImageLoading
    let openLogin: () -> Void
    let openTarget: (NotificationTarget) -> Void
    let openThread: (Int64) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(NotificationKind.allCases, id: \.self) { kind in
                    Button { store.select(kind) } label: {
                        VStack(spacing: 8) {
                            Text(kind.title).font(.body).fontWeight(store.selectedPage == kind ? .semibold : .regular)
                                .foregroundStyle(store.selectedPage == kind ? SemanticColor.primaryText : SemanticColor.secondaryText)
                            Capsule().fill(store.selectedPage == kind ? SemanticColor.primaryText : .clear).frame(width: 24, height: 3)
                        }.frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("notifications.tab.\(kind.rawValue)")
                    .accessibilityAddTraits(store.selectedPage == kind ? .isSelected : [])
                }
            }
            TiebaFlatDivider(inset: 0)
            if case .active = store.context {
                PagerContainer(
                    pageIDs: NotificationKind.allCases, selection: $store.selectedPage,
                    backgroundColor: .systemBackground, reduceMotion: reduceMotion,
                    externalSelectionGeneration: $store.selectionGeneration, contentGeneration: { _ in 0 },
                    content: { kind in
                    NotificationsListView(store: store.page(kind), imageLoader: imageLoader,
                                          openTarget: openTarget, openThread: openThread)
                })
                .accessibilityIdentifier("notifications.pager")
            } else {
                VStack(spacing: 12) {
                    Text("登录后查看消息").foregroundStyle(SemanticColor.secondaryText)
                    Button("登录", action: openLogin).accessibilityIdentifier("notifications.login")
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(SemanticColor.background)
        .navigationTitle("消息").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新", systemImage: "arrow.clockwise") {
                    refreshTask?.cancel()
                    refreshTask = Task {
                        await store.page(store.selectedPage ?? .replies).refresh()
                        await store.refreshCountsAfterReading()
                    }
                }.accessibilityIdentifier("notifications.refresh")
            }.tiebaFlatToolbarItem()
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("app.root.notifications")
        .task(id: store.selectedPage) { await store.loadSelected() }
        .onChange(of: store.context) { _, _ in
            refreshTask?.cancel()
            refreshTask = Task { await store.loadSelected() }
        }
    }
}

private struct NotificationsListView: View {
    @Bindable var store: NotificationsListStore
    let imageLoader: any ImageLoading
    let openTarget: (NotificationTarget) -> Void
    let openThread: (Int64) -> Void
    @State private var actionTask: Task<Void, Never>?

    var body: some View {
        Group {
            if !store.items.isEmpty {
                VirtualizedList(
                    items: store.rows, backgroundColor: .systemBackground,
                    accessibilityIdentifier: "notifications.list.\(store.kind.rawValue)",
                    restoredAnchor: store.readAnchor, onPrefetch: store.prefetch, onScrollSettled: store.setAnchor
                ) { row in
                    if let item = row.item {
                        NotificationRow(item: item, imageLoader: imageLoader,
                                        open: { openTarget(item.target) }, openThread: { openThread(item.target.threadID) })
                    } else { footer(row) }
                }
            } else if store.phase == .empty {
                Text(store.kind == .replies ? "暂无回复消息" : "暂无提到我的消息")
                    .foregroundStyle(SemanticColor.secondaryText).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("notifications.empty.\(store.kind.rawValue)")
            } else if store.phase == .initialFailure {
                FullPageErrorView(title: "消息加载失败", message: failureMessage) { refresh() }
                    .accessibilityIdentifier("notifications.failure.\(store.kind.rawValue)")
            } else {
                InitialLoadingView(title: "正在加载消息")
            }
        }.background(SemanticColor.background)
    }

    private var failureMessage: String {
        if store.error == .authentication { return "登录已失效，请重新登录。" }
        return "暂时无法获取消息，请稍后重试。"
    }

    @ViewBuilder private func footer(_ row: NotificationListRow) -> some View {
        if row.phase == .loadingNextPage || row.phase == .refreshing {
            PaginationFooter(state: .loading, retry: {})
        } else if row.phase == .refreshFailure {
            Button("刷新失败，重试", action: refresh).frame(maxWidth: .infinity, minHeight: 44)
        } else if row.hasMore {
            Button(row.phase == .nextPageFailure ? "加载失败，重试" : "加载更多") {
                actionTask = Task { await store.loadNextPage() }
            }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("notifications.more.\(store.kind.rawValue)")
        } else {
            Text("已经到底了").font(.caption).foregroundStyle(SemanticColor.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("notifications.end.\(store.kind.rawValue)")
        }
    }

    private func refresh() {
        actionTask?.cancel()
        actionTask = Task { await store.refresh() }
    }
}

private struct NotificationRow: View {
    let item: TiebaNotification
    let imageLoader: any ImageLoading
    let open: () -> Void
    let openThread: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: open) {
                replyContent.contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("notifications.row.\(item.id)")
            if !item.quote.isEmpty {
                Button(action: openThread) {
                    TiebaRichTextView(runs: TiebaRichText.parse(item.quote), fontSize: 13, lineLimit: 4, interactive: false)
                        .padding(8).frame(minHeight: 44)
                        .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("notifications.quote.\(item.id)")
                .accessibilityHint("打开对应帖子")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .foregroundStyle(SemanticColor.primaryText)
        TiebaFlatDivider(inset: 16)
    }

    private var replyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TiebaAvatarView(resource: item.author.avatarResource, imageLoader: imageLoader)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.author.displayName).font(.subheadline).fontWeight(.semibold)
                        TiebaUserLevelBadge(level: item.author.levelID)
                    }
                    TiebaMetadataRow(values: [item.createdAt.map { TiebaDateText.date($0) } ?? ""])
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            TiebaRichTextView(runs: TiebaRichText.parse(item.content), interactive: false)
        }
    }
}
