import Foundation

#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
struct HarnessHTTPCallID: Hashable, Sendable {
    let rawValue: UInt64
}

struct HarnessPendingHTTPCall: Equatable, Sendable {
    let id: HarnessHTTPCallID
    let request: HTTPRequest
}

enum HarnessHTTPEvent: Equatable, Sendable {
    case cancelled(HarnessHTTPCallID)
    case failed(HarnessHTTPCallID, HTTPClientError)
    case started(HarnessHTTPCallID)
    case succeeded(HarnessHTTPCallID)
}

enum HarnessHTTPControlError: Error, Equatable, Sendable {
    case unknownCall
}

enum HarnessHTTPDefaultBehavior: Equatable, Sendable {
    case controlled
    case failure(HTTPClientError)
}

actor HarnessMockHTTPClient: HTTPClient {
    private struct PendingCall {
        let request: HTTPRequest
        let gate: HarnessContinuationGate<HTTPResponse>
    }

    private struct CountObserver {
        let id: UInt64
        let expectedCount: Int
        let gate: HarnessContinuationGate<Void>
    }

    private let defaultBehavior: HarnessHTTPDefaultBehavior
    private var nextCallID: UInt64 = 1
    private var nextObserverID: UInt64 = 1
    private var pending: [HarnessHTTPCallID: PendingCall] = [:]
    private var recordedEvents: [HarnessHTTPEvent] = []
    private var countObservers: [CountObserver] = []

    init(defaultBehavior: HarnessHTTPDefaultBehavior = .controlled) {
        self.defaultBehavior = defaultBehavior
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        try Task.checkCancellation()

        let callID = HarnessHTTPCallID(rawValue: nextCallID)
        nextCallID += 1
        recordedEvents.append(.started(callID))

        if case let .failure(error) = defaultBehavior {
            recordedEvents.append(.failed(callID, error))
            throw error
        }

        let gate = HarnessContinuationGate<HTTPResponse>()
        pending[callID] = PendingCall(request: request, gate: gate)
        resumeCountObservers()

        do {
            return try await withTaskCancellationHandler {
                try await gate.wait()
            } onCancel: {
                gate.cancel()
            }
        } catch {
            if error is CancellationError {
                if pending.removeValue(forKey: callID) != nil {
                    recordedEvents.append(.cancelled(callID))
                }
            }
            throw error
        }
    }

    func pendingCalls() -> [HarnessPendingHTTPCall] {
        pending.map { id, call in
            HarnessPendingHTTPCall(id: id, request: call.request)
        }
        .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    func waitForPendingCallCount(
        _ expectedCount: Int,
        registrationSignal: HarnessContinuationGate<Void>? = nil
    ) async throws {
        try Task.checkCancellation()
        if pending.count >= expectedCount {
            return
        }

        let observerID = nextObserverID
        nextObserverID += 1
        let gate = HarnessContinuationGate<Void>()
        countObservers.append(
            CountObserver(
                id: observerID,
                expectedCount: expectedCount,
                gate: gate
            )
        )
        registrationSignal?.succeed(())

        do {
            try await withTaskCancellationHandler {
                try await gate.wait()
            } onCancel: {
                gate.cancel()
            }
        } catch {
            countObservers.removeAll { $0.id == observerID }
            throw error
        }
    }

    func pendingCountObserverCount() -> Int {
        countObservers.count
    }

    func succeed(
        _ callID: HarnessHTTPCallID,
        with response: HTTPResponse
    ) throws {
        guard let call = pending[callID], call.gate.succeed(response) else {
            throw HarnessHTTPControlError.unknownCall
        }
        pending.removeValue(forKey: callID)
        recordedEvents.append(.succeeded(callID))
    }

    func fail(
        _ callID: HarnessHTTPCallID,
        with error: HTTPClientError
    ) throws {
        guard let call = pending[callID], call.gate.fail(error) else {
            throw HarnessHTTPControlError.unknownCall
        }
        pending.removeValue(forKey: callID)
        recordedEvents.append(.failed(callID, error))
    }

    func events() -> [HarnessHTTPEvent] {
        recordedEvents
    }

    private func resumeCountObservers() {
        var remaining: [CountObserver] = []
        for observer in countObservers {
            if pending.count >= observer.expectedCount {
                observer.gate.succeed(())
            } else {
                remaining.append(observer)
            }
        }
        countObservers = remaining
    }
}

actor HarnessLatestValueProbe<Value: Sendable> {
    private var currentGeneration: UInt64 = 0
    private var committedValue: Value?

    func begin() -> UInt64 {
        currentGeneration += 1
        return currentGeneration
    }

    func commit(_ value: Value, generation: UInt64) -> Bool {
        guard generation == currentGeneration else {
            return false
        }
        committedValue = value
        return true
    }

    func value() -> Value? {
        committedValue
    }
}
#endif
