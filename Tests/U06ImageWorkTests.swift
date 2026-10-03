import Foundation
import Testing
@testable import TiebaLite

struct U06ImageWorkTests {
    @Test func boundedWorkSharesDecodeAndPromotesForegroundAheadOfQueuedPreload() async throws {
        let pool = ImageWorkPool<Int>(limit: 2)
        let order = ImageWorkTestOrder()
        let gateOne = HarnessContinuationGate<Void>()
        let gateTwo = HarnessContinuationGate<Void>()
        let first = Task { try await pool.value(for: "one") { try await gateOne.wait(); return 1 } }
        let second = Task { try await pool.value(for: "two") { try await gateTwo.wait(); return 2 } }
        while await pool.counts.active != 2 { await Task.yield() }
        let duplicate = Task { try await pool.value(for: "one") { Issue.record("Duplicate decode"); return -1 } }
        while await pool.merged == 0 { await Task.yield() }
        let preload = Task { try await pool.value(for: "preload", foreground: false) { await order.append(4); return 4 } }
        while await pool.counts.queued != 1 { await Task.yield() }
        let foreground = Task { try await pool.value(for: "foreground") { await order.append(3); return 3 } }
        while await pool.counts.queued != 2 { await Task.yield() }
        #expect(await pool.counts.active == 2)
        #expect(await order.values.isEmpty)
        gateOne.succeed(())
        #expect(try await foreground.value == 3)
        #expect(try await preload.value == 4)
        #expect(await order.values == [3, 4])
        #expect(try await first.value == 1)
        #expect(try await duplicate.value == 1)
        gateTwo.succeed(())
        #expect(try await second.value == 2)
    }

    @Test func lastConsumerCancelsUnderlyingWorkAndRetainsSlotUntilWorkExits() async throws {
        let pool = ImageWorkPool<Int>(limit: 1)
        let gate = HarnessContinuationGate<Void>()
        let cancelled = HarnessContinuationGate<Void>()
        let first = Task {
            try await pool.value(for: "same") {
                try await withTaskCancellationHandler { try await gate.wait() } onCancel: { cancelled.succeed(()) }
                return 1
            }
        }
        while await pool.counts.active == 0 { await Task.yield() }
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        try await cancelled.wait()
        let replacement = Task { try await pool.value(for: "same") { 2 } }
        while await pool.counts.queued == 0 { await Task.yield() }
        #expect(await pool.counts.active == 1)
        gate.succeed(())
        #expect(try await replacement.value == 2)
        #expect(await pool.counts.subscribers == 0)
    }
}
