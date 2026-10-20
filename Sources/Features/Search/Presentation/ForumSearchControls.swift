import SwiftUI

@MainActor
struct ForumSearchControls: View {
    @Bindable var store: SearchStore
    let resignFocus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 20) {
                ForEach(ForumSearchMode.allCases, id: \.self) { mode in
                    let selected = mode == store.selectedForumMode
                    Button {
                        resignFocus()
                        Task { await store.selectForumMode(mode) }
                    } label: {
                        VStack(spacing: 5) {
                            Text(mode.title).font(.subheadline.weight(selected ? .semibold : .regular))
                            Capsule().fill(selected ? Color.accentColor : .clear).frame(width: 16, height: 3)
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                    .accessibilityIdentifier("search.forum-mode.\(mode.rawValue)")
                }
                Spacer(minLength: 4)
                Menu {
                    ForEach([SearchSort.newest, .relevance], id: \.self) { sort in
                        Button {
                            resignFocus()
                            Task { await store.selectSort(sort) }
                        } label: {
                            if sort == store.selectedSort { Label(title(sort), systemImage: "checkmark") } else { Text(title(sort)) }
                        }
                        .accessibilityIdentifier("search.forum-sort.\(sort.rawValue)")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(title(store.selectedSort))
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .font(.caption).frame(minHeight: 44)
                }
                .accessibilityIdentifier("search.forum-sort")
                .accessibilityValue(title(store.selectedSort))
            }
            .buttonStyle(.plain).foregroundStyle(SemanticColor.primaryText)
            .padding(.horizontal, 16)
            if case let .forum(forum) = store.scope {
                Text("以下内容来自\(forum.forumName.rawValue)吧的搜索结果")
                    .font(.caption).foregroundStyle(SemanticColor.secondaryText)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .accessibilityIdentifier("search.forum-scope")
            }
        }
    }

    private func title(_ sort: SearchSort) -> String { sort == .relevance ? "相关在前" : "新帖在前" }
}

@MainActor
struct ForumSearchHistoryView: View {
    @Bindable var store: SearchStore
    let submit: () -> Void
    @State private var expanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("搜索历史").font(.subheadline.bold())
                    Spacer()
                    Button { Task { await store.clearHistory() } } label: {
                        Image(systemName: "trash").font(.caption).frame(width: 44, height: 44)
                    }
                    .foregroundStyle(SemanticColor.secondaryText)
                    .accessibilityLabel("清空搜索历史")
                    .accessibilityIdentifier("search.history.clear")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(Array(store.searchHistory.prefix(expanded ? 20 : 8).enumerated()), id: \.element) { index, word in
                        Button {
                            store.setDraftKeyword(word)
                            submit()
                        } label: {
                            Text(word).font(.caption).lineLimit(1).padding(.horizontal, 12).padding(.vertical, 7)
                                .frame(maxWidth: .infinity).background(TiebaParityTokens.neutralFill, in: Capsule())
                                .frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("search.history.word.\(index)")
                    }
                }
                if store.searchHistory.count > 8 {
                    Button(expanded ? "收起" : "展开全部") { expanded.toggle() }
                        .font(.caption).frame(minHeight: 44).accessibilityIdentifier("search.history.expand")
                }
            }
            .buttonStyle(.plain).foregroundStyle(SemanticColor.primaryText).padding(.horizontal, 16)
        }
        .accessibilityIdentifier("search.history")
    }
}
