/// Verified 22.11.1 page-origin values, separate from business/draft identity.
/// Unknown entrances remain the existing unspecified branch, never inferred
/// from the current tab after navigation has already happened.
enum ThreadReadingEntry: Int, Codable, Sendable {
    case unspecified = 0
    case recommendations = 3
    case forum = 5
    case history = 30
    case search = 34
    case contentLink = 14
    case universalLink = 32
    case replyNotificationQuote = 29
    case replyNotification = 37
    case mentionNotification = 39

    static func notification(_ kind: NotificationKind, opensQuotedThread: Bool) -> Self {
        switch kind {
        case .replies: opensQuotedThread ? .replyNotificationQuote : .replyNotification
        case .mentions: .mentionNotification
        }
    }
}
