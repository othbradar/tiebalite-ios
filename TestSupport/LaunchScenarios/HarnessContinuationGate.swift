import Synchronization

#if UITESTING || TEST_SUPPORT
enum HarnessContinuationGateError: Error, Equatable, Sendable {
    case multipleWaiters
}

final class HarnessContinuationGate<Value: Sendable>: Sendable {
    private enum State {
        case idle
        case waiting(CheckedContinuation<Value, any Error>)
        case resolved(Result<Value, any Error>)
        case consumed
    }

    private enum RegistrationAction {
        case suspend
        case resume(Result<Value, any Error>)
        case reject
    }

    private enum ResolutionAction {
        case store
        case resume(CheckedContinuation<Value, any Error>)
        case reject
    }

    private let state = Mutex<State>(.idle)

    func wait() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let action = state.withLock { storage in
                switch storage {
                case .idle:
                    storage = .waiting(continuation)
                    return RegistrationAction.suspend
                case let .resolved(result):
                    storage = .consumed
                    return RegistrationAction.resume(result)
                case .waiting, .consumed:
                    return RegistrationAction.reject
                }
            }

            switch action {
            case .suspend:
                break
            case let .resume(result):
                continuation.resume(with: result)
            case .reject:
                continuation.resume(
                    throwing: HarnessContinuationGateError.multipleWaiters
                )
            }
        }
    }

    @discardableResult
    func succeed(_ value: Value) -> Bool {
        resolve(.success(value))
    }

    @discardableResult
    func fail(_ error: any Error) -> Bool {
        resolve(.failure(error))
    }

    @discardableResult
    func cancel() -> Bool {
        fail(CancellationError())
    }

    private func resolve(_ result: Result<Value, any Error>) -> Bool {
        let action = state.withLock { storage in
            switch storage {
            case .idle:
                storage = .resolved(result)
                return ResolutionAction.store
            case let .waiting(continuation):
                storage = .consumed
                return ResolutionAction.resume(continuation)
            case .resolved, .consumed:
                return ResolutionAction.reject
            }
        }

        switch action {
        case .store:
            return true
        case let .resume(continuation):
            continuation.resume(with: result)
            return true
        case .reject:
            return false
        }
    }
}
#endif
