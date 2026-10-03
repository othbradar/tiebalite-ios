import Foundation

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
        var foreground: Bool
        var waiters: [UInt64: CheckedContinuation<Value, any Error>]
        var task: Task<Void, Never>?
    }

    private let limit: Int
    private var sequence: UInt64 = 0
    private var jobs: [UInt64: Job] = [:]
    private var byKey: [String: UInt64] = [:]
    private var running = 0
    private(set) var merged = 0

    init(limit: Int) { self.limit = max(1, limit) }

    var counts: Counts {
        Counts(active: running, queued: jobs.values.filter { $0.task == nil }.count,
               subscribers: jobs.values.reduce(0) { $0 + $1.waiters.count })
    }

    func value(
        for key: String, foreground: Bool = true,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()
        sequence &+= 1
        let subscriber = sequence
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if let id = byKey[key], var job = jobs[id] {
                    merged += 1
                    job.foreground = job.foreground || foreground
                    job.waiters[subscriber] = continuation
                    jobs[id] = job
                } else {
                    byKey[key] = subscriber
                    jobs[subscriber] = Job(id: subscriber, key: key, operation: operation, foreground: foreground,
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
        while running < limit {
            let queued = jobs.values.filter { $0.task == nil && !$0.waiters.isEmpty }
            guard var job = queued.min(by: {
                $0.foreground == $1.foreground ? $0.id < $1.id : $0.foreground
            }) else { return }
            let id = job.id
            let operation = job.operation
            running += 1
            job.task = Task(priority: job.foreground ? .userInitiated : .utility) {
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
