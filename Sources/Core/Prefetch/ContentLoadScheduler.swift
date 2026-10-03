import Foundation

/// Shared by the content repositories. Each consumer owns cancellation, not the transport task.
actor ContentLoadScheduler {
    enum Priority: Sendable { case foreground, speculative }
    struct Counts: Sendable {
        var networkForeground = 0
        var networkSpeculative = 0
        var foreground = 0
        var speculative = 0
        var merged = 0
        var cacheHits = 0
        var activeSpeculative = 0
        var queued = 0
    }
    private struct Payload: Sendable { let value: any Sendable }
    private struct Flight {
        let key: String
        let operation: @Sendable () async throws -> Payload
        var consumers: [UInt64: CheckedContinuation<Payload, any Error>]
        var foreground: Bool
        var task: Task<Void, Never>?
    }
    private var flights: [UInt64: Flight] = [:]
    private var keys: [String: UInt64] = [:]
    private var queue: [UInt64] = []
    private var serial: UInt64 = 0
    private var counts = Counts()

    func diagnostics() -> Counts {
        var value = counts
        value.activeSpeculative = speculativeCount
        value.queued = queue.count
        return value
    }

    func sourceStarted(priority: Priority) {
        if priority == .foreground { counts.networkForeground += 1 } else { counts.networkSpeculative += 1 }
    }

    func cacheHit() { counts.cacheHits += 1 }

    func load<Value: Sendable>(key: String, priority: Priority,
                               operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
        serial &+= 1
        let consumer = serial
        let payload = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                attach(key: key, consumer: consumer, priority: priority, continuation: continuation,
                       operation: { Payload(value: try await operation()) })
            }
        } onCancel: {
            Task { await self.cancel(consumer: consumer) }
        }
        try Task.checkCancellation()
        guard let value = payload.value as? Value else { throw EndpointExecutionError.mapping }
        return value
    }

    private func attach(key: String, consumer: UInt64, priority: Priority,
                        continuation: CheckedContinuation<Payload, any Error>,
                        operation: @escaping @Sendable () async throws -> Payload) {
        if let id = keys[key], var flight = flights[id] {
            counts.merged += 1
            flight.consumers[consumer] = continuation
            if priority == .foreground { flight.foreground = true }
            flights[id] = flight
            if flight.foreground, flight.task == nil { start(id) }
            drain()
            return
        }
        if priority == .speculative, speculativeCount >= 2, queue.count >= 8 {
            continuation.resume(throwing: CancellationError())
            return
        }
        flights[consumer] = Flight(key: key, operation: operation, consumers: [consumer: continuation],
                                   foreground: priority == .foreground)
        keys[key] = consumer
        if priority == .foreground || speculativeCount < 2 { start(consumer) } else { queue.append(consumer) }
    }

    private var speculativeCount: Int {
        flights.values.filter { !$0.foreground && $0.task != nil }.count
    }

    private func start(_ id: UInt64) {
        guard let flight = flights[id], flight.task == nil else { return }
        queue.removeAll { $0 == id }
        if flight.foreground { counts.foreground += 1 } else { counts.speculative += 1 }
        flights[id]?.task = Task(priority: flight.foreground ? .userInitiated : .utility) {
            let result: Result<Payload, any Error>
            do { result = .success(try await flight.operation()) } catch { result = .failure(error) }
            self.finish(id, result: result)
        }
    }

    private func finish(_ id: UInt64, result: Result<Payload, any Error>) {
        guard let flight = flights.removeValue(forKey: id) else { return }
        if keys[flight.key] == id { keys[flight.key] = nil }
        for continuation in flight.consumers.values { continuation.resume(with: result) }
        drain()
    }

    private func cancel(consumer: UInt64) {
        guard let id = flights.first(where: { $0.value.consumers[consumer] != nil })?.key,
              let continuation = flights[id]?.consumers.removeValue(forKey: consumer) else { return }
        continuation.resume(throwing: CancellationError())
        guard let flight = flights[id], flight.consumers.isEmpty else { return }
        if keys[flight.key] == id { keys[flight.key] = nil }
        if let task = flight.task {
            // Keep its slot until the transport actually exits, including cancellation-ignoring sources.
            task.cancel()
        } else {
            flights[id] = nil
            queue.removeAll { $0 == id }
        }
        drain()
    }

    private func drain() {
        while speculativeCount < 2, let id = queue.first { start(id) }
    }
}
