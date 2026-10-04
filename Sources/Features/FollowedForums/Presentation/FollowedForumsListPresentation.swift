enum FollowedForumsRowID: Hashable, Sendable {
    case recent
    case heading
    case status
    case forum(Int64)
}

enum FollowedForumsRetainedStatus: Equatable, Sendable {
    case loading
    case failure
}

enum FollowedForumsRowContent: Equatable, Sendable {
    case recent([RecentForum], expanded: Bool, editing: Bool)
    case heading
    case status(FollowedForumsRetainedStatus)
    case forum(FollowedForum)
}

struct FollowedForumsRowModel: Identifiable, Equatable, Sendable {
    let content: FollowedForumsRowContent
    let avatarResource: ImageResourceDescriptor?

    var id: FollowedForumsRowID {
        switch content {
        case .recent: .recent
        case .heading: .heading
        case .status: .status
        case let .forum(forum): .forum(forum.forumID)
        }
    }
}

struct FollowedForumsListPresentation: Equatable, Sendable {
    let rows: [FollowedForumsRowModel]
    private let forumIDs: Set<Int64>

    init(
        forums: [FollowedForum],
        recent: [RecentForum],
        expanded: Bool,
        editingRecent: Bool = false,
        status: FollowedForumsRetainedStatus? = nil
    ) {
        var contents: [FollowedForumsRowContent] = []
        if !recent.isEmpty { contents.append(.recent(recent, expanded: expanded, editing: editingRecent)) }
        contents.append(.heading)
        if let status { contents.append(.status(status)) }
        var seen = Set<Int64>()
        for forum in forums where forum.forumID > 0 && seen.insert(forum.forumID).inserted {
            contents.append(.forum(forum))
        }
        rows = contents.map { content in
            let avatar: ImageResourceDescriptor?
            if case let .forum(forum) = content {
                avatar = forum.avatarResource ?? recent.first { $0.id == forum.forumID }?.avatarResource
            } else {
                avatar = nil
            }
            return FollowedForumsRowModel(content: content, avatarResource: avatar)
        }
        forumIDs = seen
    }

    func forumAnchor(for rowID: FollowedForumsRowID?) -> Int64? {
        guard case let .forum(forumID)? = rowID, forumIDs.contains(forumID) else { return nil }
        return forumID
    }

    func restoredRowID(for forumID: Int64?) -> FollowedForumsRowID? {
        guard let forumID, forumIDs.contains(forumID) else { return nil }
        return .forum(forumID)
    }
}

enum HomeForumNumber {
    // Android StringUtil.getShortNumString: truncate at one decimal place.
    static func text(_ value: Int) -> String {
        let value = max(0, value)
        guard value > 9_999 else { return String(value) }
        let tenthsOfWan = value / 1_000
        if tenthsOfWan > 9_990 {
            let tenthsOfThousandWan = (tenthsOfWan / 10) / 100
            return "\(tenthsOfThousandWan / 10).\(tenthsOfThousandWan % 10)KW"
        }
        return "\(tenthsOfWan / 10).\(tenthsOfWan % 10)W"
    }
}
