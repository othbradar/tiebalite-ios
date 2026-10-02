import SwiftUI

struct ForumTabsView: View {
    @Bindable var store: ForumHomeStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                HStack(spacing: 0) {
                    tab("最新", id: .latest)
                    Menu {
                        ForEach(ForumSortOrder.allCases, id: \.rawValue) { order in
                            Button {
                                store.selectPage(.latest)
                                Task { await store.changeQuery(.latest(order)) }
                            } label: {
                                if store.query == .latest(order) {
                                    Label(order.title, systemImage: "checkmark")
                                } else {
                                    Text(order.title)
                                }
                            }
                            .accessibilityIdentifier("forum-home.sort.\(order.rawValue)")
                        }
                        Divider()
                        Button("恢复跟随全局") {
                            store.selectPage(.latest)
                            Task { await store.followGlobalSort() }
                        }
                        .disabled(!store.hasRememberedSort)
                        .accessibilityIdentifier("forum-home.sort.follow-global")
                    } label: {
                        Image(systemName: "chevron.down").font(.caption2)
                            .frame(width: 28, height: 44)
                    }
                    .accessibilityLabel("最新排序")
                    .accessibilityValue(store.query == .latest(.creation) ? "最新发布" : "最新回复")
                    .accessibilityIdentifier("forum-home.sort")
                }
                tab("精华", id: .good)
                ForEach(store.displayedForum?.navigation.categories ?? []) { category in
                    HStack(spacing: 0) {
                        tab(category.title, id: .category(category.id))
                        if !category.sorts.isEmpty {
                            Menu {
                                ForEach(category.sorts) { sort in
                                    Button(sort.title) {
                                        store.selectPage(.category(category.id))
                                        Task {
                                            await store.pageStore(for: .category(category.id))?
                                                .changeQuery(.category(category, sort: sort.id))
                                        }
                                    }
                                    .accessibilityIdentifier("forum-home.category.\(category.id).sort.\(sort.id)")
                                }
                            } label: {
                                Image(systemName: "chevron.down").font(.caption2).frame(width: 28, height: 44)
                            }
                            .accessibilityLabel("\(category.title)排序")
                            .accessibilityIdentifier("forum-home.category.\(category.id).sort")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .foregroundStyle(SemanticColor.primaryText)
    }

    private func tab(_ title: String, id: ForumPageID) -> some View {
        Button { store.selectPage(id) } label: {
            VStack(spacing: 4) {
                Text(title).font(.subheadline.bold()).lineLimit(1)
                    .foregroundStyle(store.selectedPage == id ? SemanticColor.primaryText : SemanticColor.secondaryText)
                Capsule().fill(store.selectedPage == id ? SemanticColor.primaryText : .clear)
                    .frame(width: 20, height: 3)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(store.selectedPage == id ? [.isSelected] : [])
        .accessibilityIdentifier("forum-home.tab.\(id.accessibilityKey)")
    }
}

struct ForumGoodChips: View {
    @Bindable var store: ForumHomeStore
    let categories: [ForumGoodCategory]

    var body: some View {
        if !categories.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { category in
                        Button(category.title) { Task { await store.changeQuery(.good(category.id)) } }
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .foregroundStyle(store.query == .good(category.id) ? SemanticColor.background : SemanticColor.secondaryText)
                            .background(store.query == .good(category.id) ? SemanticColor.primaryText : TiebaParityTokens.neutralFill,
                                        in: Capsule())
                            .accessibilityAddTraits(store.query == .good(category.id) ? [.isSelected] : [])
                            .accessibilityIdentifier("forum-home.good.\(category.id)")
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
            }
        }
    }
}
