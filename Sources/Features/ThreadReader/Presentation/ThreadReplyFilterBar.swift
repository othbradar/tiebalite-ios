import SwiftUI

private struct ThreadReplyPreferencesKey: EnvironmentKey {
    static let defaultValue: (any ThreadReplyPreferences)? = nil
}

extension EnvironmentValues {
    var threadReplyPreferences: (any ThreadReplyPreferences)? {
        get { self[ThreadReplyPreferencesKey.self] }
        set { self[ThreadReplyPreferencesKey.self] = newValue }
    }
}

/// Both groups operate on the same query. No local row filtering or reordering.
struct ThreadReplyFilterBar: View {
    @ScaledMetric(relativeTo: .caption2) private var capsuleHeight = 26.0
    @Bindable var store: ThreadReaderStore
    var preferences: (any ThreadReplyPreferences)?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                authors
                Spacer(minLength: 0)
                orders
            }
            VStack(alignment: .leading, spacing: 0) {
                authors
                HStack { Spacer(minLength: 0); orders }
            }
        }
        .buttonStyle(.plain)
        .disabled(store.isNavigating)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thread-reader.filters")
    }

    private var authors: some View {
        HStack(spacing: 16) {
            author("全部回复", onlyAuthor: false, identifier: "all")
            author("只看楼主", onlyAuthor: true, identifier: "author")
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func author(_ title: String, onlyAuthor: Bool, identifier: String) -> some View {
        let selected = store.query.onlyAuthor == onlyAuthor
        return Button {
            var query = store.query
            query.onlyAuthor = onlyAuthor
            select(query)
        } label: {
            Text(title).font(.footnote.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? SemanticColor.primaryText : SemanticColor.secondaryText)
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("thread-reader.filter.\(identifier)")
    }

    private var orders: some View {
        HStack(spacing: 0) {
            ForEach(ThreadReadingOrder.allCases, id: \.self) { order in
                let selected = store.query.order == order
                Button {
                    var query = store.query
                    query.order = order
                    select(query)
                } label: {
                    Text(order.title).font(.caption2)
                        .foregroundStyle(selected ? SemanticColor.primaryText : SemanticColor.secondaryText)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 44, minHeight: capsuleHeight - 4)
                        .background {
                            if selected { Capsule().fill(SemanticColor.background) }
                        }
                        .frame(minHeight: max(44, capsuleHeight)).contentShape(Rectangle())
                }
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("thread-reader.order.\(order.rawValue)")
            }
        }
        .padding(.horizontal, 3)
        .background {
            Capsule().fill(TiebaParityTokens.neutralFill).frame(height: capsuleHeight)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func select(_ query: ThreadReadingQuery) {
        Task { await store.selectReplyQuery(query, preferences: preferences) }
    }
}

extension ThreadReaderStore {
    func selectReplyQuery(_ newQuery: ThreadReadingQuery, preferences: (any ThreadReplyPreferences)?) async {
        await selectQuery(newQuery)
        guard !Task.isCancelled, !isNavigating, query == newQuery, navigationMessage == nil else { return }
        preferences?.setReplyQuery(newQuery)
    }

    func applyReplyPreferences(_ preferences: (any ThreadReplyPreferences)?) async {
        guard let preferences, !isNavigating else { return }
        if !hasCompletedInitialLoad, query != preferences.replyQuery {
            cancel()
            query = preferences.replyQuery
        } else if query != preferences.replyQuery { await selectQuery(preferences.replyQuery) }
    }
}
