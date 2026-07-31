import Foundation

protocol AppClock: Sendable {
    var now: Date { get async }

    func sleep(for duration: Duration) async throws
}

struct SystemAppClock: AppClock {
    var now: Date {
        get async {
            Date()
        }
    }

    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}
