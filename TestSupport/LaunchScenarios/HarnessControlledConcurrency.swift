import Foundation

#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
actor HarnessControlledClock: AppClock {
    static let fixedEpoch = Date(timeIntervalSince1970: 978_307_200)

    private struct Sleeper {
        let deadline: Date
        let gate: HarnessContinuationGate<Void>
    }

    private struct CountObserver {
        let id: UInt64
        let expectedCount: Int
        let gate: HarnessContinuationGate<Void>
    }

    private var currentDate: Date
    private var nextObserverID: UInt64 = 1
    private var nextSleeperID: UInt64 = 1
    private var sleepers: [UInt64: Sleeper] = [:]
    private var countObservers: [CountObserver] = []

    init(now: Date = fixedEpoch) {
        currentDate = now
    }

    var now: Date {
        get async {
            currentDate
        }
    }

    func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        guard duration > .zero else {
            return
        }

        let sleeperID = nextSleeperID
        nextSleeperID += 1
        let deadline = currentDate.addingTimeInterval(duration.harnessTimeInterval)
        let gate = HarnessContinuationGate<Void>()
        sleepers[sleeperID] = Sleeper(deadline: deadline, gate: gate)
        resumeCountObservers()

        do {
            try await withTaskCancellationHandler {
                try await gate.wait()
            } onCancel: {
                gate.cancel()
            }
        } catch {
            sleepers.removeValue(forKey: sleeperID)
            throw error
        }
    }

    func advance(by duration: Duration) -> [UInt64] {
        currentDate = currentDate.addingTimeInterval(duration.harnessTimeInterval)
        let dueIDs = sleepers
            .filter { $0.value.deadline <= currentDate }
            .sorted { lhs, rhs in
                if lhs.value.deadline == rhs.value.deadline {
                    lhs.key < rhs.key
                } else {
                    lhs.value.deadline < rhs.value.deadline
                }
            }
            .map(\.key)

        var resumedIDs: [UInt64] = []
        for sleeperID in dueIDs {
            guard let sleeper = sleepers.removeValue(forKey: sleeperID) else {
                continue
            }
            if sleeper.gate.succeed(()) {
                resumedIDs.append(sleeperID)
            }
        }
        return resumedIDs
    }

    func pendingSleeperCount() -> Int {
        sleepers.count
    }

    func waitForSleeperCount(
        _ expectedCount: Int,
        registrationSignal: HarnessContinuationGate<Void>? = nil
    ) async throws {
        try Task.checkCancellation()
        if sleepers.count >= expectedCount {
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

    private func resumeCountObservers() {
        var remaining: [CountObserver] = []
        for observer in countObservers {
            if sleepers.count >= observer.expectedCount {
                observer.gate.succeed(())
            } else {
                remaining.append(observer)
            }
        }
        countObservers = remaining
    }
}

struct HarnessBarrierArrivalID: Hashable, Sendable {
    let rawValue: UInt64
}

enum HarnessBarrierControlError: Error, Equatable, Sendable {
    case unknownArrival
}

actor HarnessControlledBarrier {
    private struct Arrival {
        let gate: HarnessContinuationGate<Void>
    }

    private struct CountObserver {
        let id: UInt64
        let expectedCount: Int
        let gate: HarnessContinuationGate<Void>
    }

    private var nextArrivalID: UInt64 = 1
    private var nextObserverID: UInt64 = 1
    private var arrivals: [HarnessBarrierArrivalID: Arrival] = [:]
    private var countObservers: [CountObserver] = []

    func arrive() async throws {
        try Task.checkCancellation()
        let arrivalID = HarnessBarrierArrivalID(rawValue: nextArrivalID)
        nextArrivalID += 1
        let gate = HarnessContinuationGate<Void>()
        arrivals[arrivalID] = Arrival(gate: gate)
        resumeCountObservers()

        do {
            try await withTaskCancellationHandler {
                try await gate.wait()
            } onCancel: {
                gate.cancel()
            }
        } catch {
            arrivals.removeValue(forKey: arrivalID)
            throw error
        }
    }

    func pendingArrivals() -> [HarnessBarrierArrivalID] {
        arrivals.keys.sorted { $0.rawValue < $1.rawValue }
    }

    func waitForArrivalCount(
        _ expectedCount: Int,
        registrationSignal: HarnessContinuationGate<Void>? = nil
    ) async throws {
        try Task.checkCancellation()
        if arrivals.count >= expectedCount {
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

    func release(_ arrivalID: HarnessBarrierArrivalID) throws {
        guard let arrival = arrivals[arrivalID], arrival.gate.succeed(()) else {
            throw HarnessBarrierControlError.unknownArrival
        }
        arrivals.removeValue(forKey: arrivalID)
    }

    private func resumeCountObservers() {
        var remaining: [CountObserver] = []
        for observer in countObservers {
            if arrivals.count >= observer.expectedCount {
                observer.gate.succeed(())
            } else {
                remaining.append(observer)
            }
        }
        countObservers = remaining
    }
}

enum HarnessIDGenerationError: Error, Equatable, Sendable {
    case exhausted
}

actor HarnessSequenceIDGenerator: IDGenerator {
    private var values: [OperationID]
    private var nextIndex = 0

    init(values: [OperationID]) {
        self.values = values
    }

    func next() async throws -> OperationID {
        guard values.indices.contains(nextIndex) else {
            throw HarnessIDGenerationError.exhausted
        }
        let value = values[nextIndex]
        nextIndex += 1
        return value
    }
}

private extension Duration {
    var harnessTimeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
#endif
