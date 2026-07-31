import Foundation
import Testing
@testable import TiebaLite

struct ControlledConcurrencyTests {
    @Test
    func controlledClockAdvancesWithoutWallTime() async throws {
        let clock = HarnessControlledClock()
        let sleeper = Task {
            try await clock.sleep(for: .seconds(10))
        }

        try await clock.waitForSleeperCount(1)
        let beforeAdvance = await clock.pendingSleeperCount()
        #expect(beforeAdvance == 1)

        let earlyResumptions = await clock.advance(by: .seconds(9))
        #expect(earlyResumptions.isEmpty)
        let stillPending = await clock.pendingSleeperCount()
        #expect(stillPending == 1)

        let dueResumptions = await clock.advance(by: .seconds(1))
        #expect(dueResumptions.count == 1)
        try await sleeper.value
        let elapsed = await clock.now
        #expect(elapsed == HarnessControlledClock.fixedEpoch.addingTimeInterval(10))
    }

    @Test
    func controlledClockCancellationIsObservable() async throws {
        let clock = HarnessControlledClock()
        let sleeper = Task {
            try await clock.sleep(for: .seconds(30))
        }

        try await clock.waitForSleeperCount(1)
        sleeper.cancel()
        let resumed = await clock.advance(by: .seconds(30))
        #expect(resumed.isEmpty)

        do {
            try await sleeper.value
            Issue.record("Expected controlled sleep cancellation")
        } catch is CancellationError {
            let pending = await clock.pendingSleeperCount()
            #expect(pending == 0)
        } catch {
            Issue.record("Cancellation was mapped to an unrelated error")
        }
    }

    @Test
    func barrierArrivalReleaseAndCancellationAreExplicit() async throws {
        let barrier = HarnessControlledBarrier()
        let first = Task {
            try await barrier.arrive()
        }
        try await barrier.waitForArrivalCount(1)
        let firstArrival = try #require(await barrier.pendingArrivals().first)

        let second = Task {
            try await barrier.arrive()
        }

        try await barrier.waitForArrivalCount(2)
        let arrivals = await barrier.pendingArrivals()
        #expect(arrivals.count == 2)
        let secondArrival = try #require(
            arrivals.first { $0 != firstArrival }
        )

        try await barrier.release(secondArrival)
        try await second.value

        first.cancel()
        do {
            try await barrier.release(firstArrival)
            Issue.record("Release must not replace an earlier cancellation")
        } catch let error as HarnessBarrierControlError {
            #expect(error == .unknownArrival)
        }
        do {
            try await first.value
            Issue.record("Expected barrier cancellation")
        } catch is CancellationError {
            let remaining = await barrier.pendingArrivals()
            #expect(remaining.isEmpty)
        } catch {
            Issue.record("Barrier cancellation changed error category")
        }
    }

    @Test
    func controlCountWaitersHonorPreCancellation() async {
        let clock = HarnessControlledClock()
        let barrier = HarnessControlledBarrier()

        let clockWaiter = Task {
            withUnsafeCurrentTask { currentTask in
                currentTask?.cancel()
            }
            try await clock.waitForSleeperCount(1)
        }
        let barrierWaiter = Task {
            withUnsafeCurrentTask { currentTask in
                currentTask?.cancel()
            }
            try await barrier.waitForArrivalCount(1)
        }

        do {
            try await clockWaiter.value
            Issue.record("Expected sleeper-count waiter cancellation")
        } catch is CancellationError {
            #expect(await clock.pendingSleeperCount() == 0)
        } catch {
            Issue.record("Sleeper-count waiter changed error category")
        }

        do {
            try await barrierWaiter.value
            Issue.record("Expected arrival-count waiter cancellation")
        } catch is CancellationError {
            #expect(await barrier.pendingArrivals().isEmpty)
        } catch {
            Issue.record("Arrival-count waiter changed error category")
        }
    }

    @Test
    func registeredCountWaitersCanBeCancelledAndRemoved() async throws {
        let clock = HarnessControlledClock()
        let barrier = HarnessControlledBarrier()
        let client = HarnessMockHTTPClient()
        let clockRegistered = HarnessContinuationGate<Void>()
        let barrierRegistered = HarnessContinuationGate<Void>()
        let clientRegistered = HarnessContinuationGate<Void>()

        let clockWaiter = Task {
            try await clock.waitForSleeperCount(
                1,
                registrationSignal: clockRegistered
            )
        }
        let barrierWaiter = Task {
            try await barrier.waitForArrivalCount(
                1,
                registrationSignal: barrierRegistered
            )
        }
        let clientWaiter = Task {
            try await client.waitForPendingCallCount(
                1,
                registrationSignal: clientRegistered
            )
        }

        try await clockRegistered.wait()
        try await barrierRegistered.wait()
        try await clientRegistered.wait()
        clockWaiter.cancel()
        barrierWaiter.cancel()
        clientWaiter.cancel()

        do {
            try await clockWaiter.value
            Issue.record("Expected registered clock waiter cancellation")
        } catch is CancellationError {
            #expect(await clock.pendingCountObserverCount() == 0)
        } catch {
            Issue.record("Registered clock waiter changed error category")
        }

        do {
            try await barrierWaiter.value
            Issue.record("Expected registered barrier waiter cancellation")
        } catch is CancellationError {
            #expect(await barrier.pendingCountObserverCount() == 0)
        } catch {
            Issue.record("Registered barrier waiter changed error category")
        }

        do {
            try await clientWaiter.value
            Issue.record("Expected registered client waiter cancellation")
        } catch is CancellationError {
            #expect(await client.pendingCountObserverCount() == 0)
        } catch {
            Issue.record("Registered client waiter changed error category")
        }
    }

    @Test
    func deterministicIDsNeverFallBackToRandomValues() async throws {
        let generator = HarnessSequenceIDGenerator(values: [
            OperationID(sequence: 41),
            OperationID(sequence: 42)
        ])

        let first = try await generator.next()
        let second = try await generator.next()
        #expect(first == OperationID(sequence: 41))
        #expect(second == OperationID(sequence: 42))

        do {
            _ = try await generator.next()
            Issue.record("Expected deterministic ID exhaustion")
        } catch let error as HarnessIDGenerationError {
            #expect(error == .exhausted)
        } catch {
            Issue.record("Unexpected ID generation error")
        }
    }
}
