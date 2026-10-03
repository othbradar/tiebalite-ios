import Foundation
import Synchronization

/// Shared across the lookup and network queues so a foreground subscriber can
/// promote a resource even if it has already left the lookup stage.
final class ImageWorkPriority: Sendable {
    private let foreground: Mutex<Bool>
    init(foreground: Bool) { self.foreground = Mutex(foreground) }
    var isForeground: Bool { foreground.withLock { $0 } }
    func promote() { foreground.withLock { $0 = true } }
}

/// A cancelled consumer releases only its subscription. Running work retains its slot until it exits.
actor ImageWorkPool<Value: Sendable> {
    struct Counts: Sendable {
        let active: Int
        let queued: Int
        let subscribers: Int
    }
    private struct Job {
        let id: UInt64
        let key: String
        let operation: @Sendable () async throws -> Value
        let priority: ImageWorkPriority
        var waiters: [UInt64: CheckedContinuation<Value, any Error>]
        var task: Task<Void, Never>?
    }

    private let limit: Int?
    private var sequence: UInt64 = 0
    private var jobs: [UInt64: Job] = [:]
    private var byKey: [String: UInt64] = [:]
    private var running = 0
    private(set) var merged = 0

    // nil provides subscription/single-flight ownership only. Actual disk/network
    // work must still enter its own bounded pool; it must not hold a download slot while looking up disk.
    init(limit: Int?) { self.limit = limit.map { max(1, $0) } }

    var counts: Counts {
        Counts(active: running, queued: jobs.values.filter { $0.task == nil }.count,
               subscribers: jobs.values.reduce(0) { $0 + $1.waiters.count })
    }

    func priority(for key: String) -> ImageWorkPriority? { byKey[key].flatMap { jobs[$0]?.priority } }

    func value(
        for key: String, foreground: Bool = true, sharedPriority: ImageWorkPriority? = nil,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()
        sequence &+= 1
        let subscriber = sequence
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if let id = byKey[key], var job = jobs[id] {
                    merged += 1
                    if foreground { job.priority.promote() }
                    job.waiters[subscriber] = continuation
                    jobs[id] = job
                } else {
                    byKey[key] = subscriber
                    let priority = sharedPriority ?? ImageWorkPriority(foreground: foreground)
                    if foreground { priority.promote() }
                    jobs[subscriber] = Job(id: subscriber, key: key, operation: operation, priority: priority,
                                           waiters: [subscriber: continuation])
                }
                drain()
            }
        } onCancel: {
            Task { await self.cancel(subscriber) }
        }
    }

    func cancelAll() {
        for id in Array(jobs.keys) {
            guard var job = jobs[id] else { continue }
            for waiter in job.waiters.values { waiter.resume(throwing: CancellationError()) }
            job.waiters.removeAll()
            job.task?.cancel()
            jobs[id] = job.task == nil ? nil : job
        }
        byKey.removeAll()
    }

    private func cancel(_ subscriber: UInt64) {
        guard let id = jobs.first(where: { $0.value.waiters[subscriber] != nil })?.key,
              var job = jobs[id], let waiter = job.waiters.removeValue(forKey: subscriber) else { return }
        waiter.resume(throwing: CancellationError())
        if job.waiters.isEmpty {
            if byKey[job.key] == id { byKey[job.key] = nil }
            job.task?.cancel()
        }
        jobs[id] = job.waiters.isEmpty && job.task == nil ? nil : job
        drain()
    }

    private func drain() {
        while limit.map({ running < $0 }) ?? true {
            let queued = jobs.values.filter { $0.task == nil && !$0.waiters.isEmpty }
            guard var job = queued.min(by: {
                $0.priority.isForeground == $1.priority.isForeground ? $0.id < $1.id : $0.priority.isForeground
            }) else { return }
            let id = job.id
            let operation = job.operation
            running += 1
            job.task = Task(priority: job.priority.isForeground ? .userInitiated : .utility) {
                let result: Result<Value, any Error>
                do { result = .success(try await operation()) } catch { result = .failure(error) }
                self.finish(id, result: result)
            }
            jobs[id] = job
        }
    }

    private func finish(_ id: UInt64, result: Result<Value, any Error>) {
        guard let job = jobs.removeValue(forKey: id) else { return }
        running -= 1
        if byKey[job.key] == id { byKey[job.key] = nil }
        for waiter in job.waiters.values { waiter.resume(with: result) }
        drain()
    }
}
