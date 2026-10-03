import Foundation
import Testing
@testable import TiebaLite

struct U04ContentSchedulerTests {
    @Test func foregroundTakesOverAndSurvivesSpeculativeCancellation() async throws {
        let scheduler = ContentLoadScheduler()
        let started = HarnessContinuationGate<Void>()
        let release = HarnessContinuationGate<Void>()
        let prefetch = Task { try await scheduler.load(key: "same", priority: .speculative) {
            started.succeed(())
            try await release.wait()
            return 42
        } }
        try await started.wait()
        let foreground = Task { try await scheduler.load(key: "same", priority: .foreground) { 99 } }
        await waitFor(scheduler) { $0.merged == 1 }
        prefetch.cancel()
        release.succeed(())
        #expect(try await foreground.value == 42)
        do { _ = try await prefetch.value; Issue.record("Canceled consumer returned a value") } catch is CancellationError {}
        let counts = await scheduler.diagnostics()
        #expect(counts.speculative == 1 && counts.foreground == 0 && counts.merged == 1)
    }

    @Test func twoSpeculativeSlotsBoundedQueueAndForegroundBypassesQueue() async throws {
        let scheduler = ContentLoadScheduler()
        let releases = (0..<10).map { _ in HarnessContinuationGate<Void>() }
        let tasks = (0..<10).map { index in Task {
            try await scheduler.load(key: "key-\(index)", priority: .speculative) {
                try await releases[index].wait()
                return index
            }
        } }
        await waitFor(scheduler) { $0.activeSpeculative == 2 && $0.queued == 8 }
        #expect(try await scheduler.load(key: "clicked", priority: .foreground) { 123 } == 123)
        let counts = await scheduler.diagnostics()
        #expect(counts.speculative == 2 && counts.foreground == 1)
        let overflow = Task { try await scheduler.load(key: "overflow", priority: .speculative) { 0 } }
        do { _ = try await overflow.value; Issue.record("Queue exceeded its bound") } catch is CancellationError {}
        tasks.forEach { $0.cancel() }
        releases.forEach { $0.succeed(()) }
        for task in tasks { _ = try? await task.value }
    }

    @Test func lastCancellationRetainsItsSlotUntilTransportActuallyExits() async throws {
        let scheduler = ContentLoadScheduler()
        let releases = (0..<2).map { _ in HarnessContinuationGate<Void>() }
        let tasks = (0..<2).map { index in Task {
            try await scheduler.load(key: "held-\(index)", priority: .speculative) {
                try await releases[index].wait()
                return index
            }
        } }
        await waitFor(scheduler) { $0.activeSpeculative == 2 }
        tasks[0].cancel()
        do { _ = try await tasks[0].value; Issue.record("Last waiter was not canceled") } catch is CancellationError {}
        let third = Task { try await scheduler.load(key: "third", priority: .speculative) { 3 } }
        await waitFor(scheduler) { $0.queued == 1 }
        #expect(await scheduler.diagnostics().speculative == 2)
        releases[0].succeed(())
        #expect(try await third.value == 3)
        releases[1].succeed(())
        _ = try await tasks[1].value
    }

    @Test func policyAndScopeStopNewRequestsWhenDisabled() async {
        #expect(ContentPrefetchMode.unmetered.permits(connected: true, expensive: false, constrained: false, lowPower: false, active: true))
        for mode in ContentPrefetchMode.allCases {
            #expect(!mode.permits(connected: true, expensive: false, constrained: true, lowPower: false, active: true))
            #expect(!mode.permits(connected: true, expensive: false, constrained: false, lowPower: true, active: true))
            #expect(!mode.permits(connected: true, expensive: false, constrained: false, lowPower: false, active: false))
        }
        #expect(!ContentPrefetchMode.unmetered.permits(connected: true, expensive: true, constrained: false, lowPower: false, active: true))
        #expect(ContentPrefetchMode.allNetworks.permits(
            connected: true, expensive: true, constrained: false, lowPower: false, active: true))
        let scope = await ContentPrefetchScope(allowed: { false })
        await scope.submit([("unused", { Issue.record("Disabled prefetch started") })])
        await scope.cancel()
    }

    private func waitFor(_ scheduler: ContentLoadScheduler, _ predicate: (ContentLoadScheduler.Counts) -> Bool) async {
        // Cooperative scheduling only, no clock-based delay or production polling.
        for _ in 0..<10_000 {
            if predicate(await scheduler.diagnostics()) { return }
            await Task.yield()
        }
        Issue.record("Scheduler did not reach the observable state")
    }
}
