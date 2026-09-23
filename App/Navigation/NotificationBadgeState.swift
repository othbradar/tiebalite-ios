import Observation

@MainActor
protocol NotificationCountSource {
    var unreadCount: Int { get }
}

/// Production remains empty until R11 connects a verified message-count source.
struct UnavailableNotificationCountSource: NotificationCountSource {
    let unreadCount = 0
}

@MainActor
@Observable
final class NotificationBadgeState: NotificationCountSource {
    private(set) var unreadCount: Int

    init(unreadCount: Int) {
        self.unreadCount = max(0, unreadCount)
    }

    func update(unreadCount: Int) {
        self.unreadCount = max(0, unreadCount)
    }
}

enum NotificationBadgePresentation {
    static func text(for count: Int) -> String? {
        guard count > 0 else { return nil }
        return count > 99 ? "99+" : String(count)
    }
}
