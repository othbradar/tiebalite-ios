import Foundation
import Testing
@testable import TiebaLite

struct MockHTTPClientTests {
    @Test
    func successAndTypedFailureAreExplicitlyControlled() async throws {
        let client = HarnessMockHTTPClient()
        let request = try makeRequest()
        let successTask = Task {
            try await client.execute(request)
        }

        try await client.waitForPendingCallCount(1)
        let successCall = try #require(await client.pendingCalls().first)
        let response = HTTPResponse(statusCode: 200, body: Data("ok".utf8))
        try await client.succeed(successCall.id, with: response)
        #expect(try await successTask.value == response)

        let failureTask = Task {
            try await client.execute(request)
        }
        try await client.waitForPendingCallCount(1)
        let failureCall = try #require(await client.pendingCalls().first)
        try await client.fail(failureCall.id, with: .offline)

        do {
            _ = try await failureTask.value
            Issue.record("Expected the typed offline failure")
        } catch let error as HTTPClientError {
            #expect(error == .offline)
        } catch {
            Issue.record("Mock failure escaped the HTTP error taxonomy")
        }
    }

    @Test
    func taskCancellationRemainsCancellationErrorAndClearsPendingCall() async throws {
        let client = HarnessMockHTTPClient()
        let task = Task {
            try await client.execute(makeRequest())
        }

        try await client.waitForPendingCallCount(1)
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected request cancellation")
        } catch is CancellationError {
            let pending = await client.pendingCalls()
            #expect(pending.isEmpty)
            let events = await client.events()
            #expect(events.contains { event in
                if case .cancelled = event {
                    return true
                }
                return false
            })
        } catch {
            Issue.record("Cancellation was mapped to a user-facing transport error")
        }
    }

    @Test
    func responsesCanFinishInReverseOrderWithoutCrossingCallIdentity() async throws {
        let client = HarnessMockHTTPClient()
        let request = try makeRequest()
        let firstTask = Task {
            try await client.execute(request)
        }
        try await client.waitForPendingCallCount(1)
        let firstCall = try #require(await client.pendingCalls().first)

        let secondTask = Task {
            try await client.execute(request)
        }
        try await client.waitForPendingCallCount(2)
        let calls = await client.pendingCalls()
        let secondCall = try #require(calls.first { $0.id != firstCall.id })

        let newerResponse = HTTPResponse(statusCode: 200, body: Data("new".utf8))
        try await client.succeed(secondCall.id, with: newerResponse)
        #expect(try await secondTask.value == newerResponse)

        let olderResponse = HTTPResponse(statusCode: 200, body: Data("old".utf8))
        try await client.succeed(firstCall.id, with: olderResponse)
        #expect(try await firstTask.value == olderResponse)
    }

    @Test
    func staleResponseCannotReplaceLatestCommittedValue() async throws {
        let client = HarnessMockHTTPClient()
        let probe = HarnessLatestValueProbe<Data>()
        let request = try makeRequest()

        let oldGeneration = await probe.begin()
        let oldTask = Task {
            try await client.execute(request)
        }
        try await client.waitForPendingCallCount(1)
        let oldCall = try #require(await client.pendingCalls().first)

        let newGeneration = await probe.begin()
        let newTask = Task {
            try await client.execute(request)
        }
        try await client.waitForPendingCallCount(2)
        let newCall = try #require(
            await client.pendingCalls().first { $0.id != oldCall.id }
        )

        let newBody = Data("new".utf8)
        try await client.succeed(
            newCall.id,
            with: HTTPResponse(statusCode: 200, body: newBody)
        )
        let newResponse = try await newTask.value
        #expect(await probe.commit(newResponse.body, generation: newGeneration))

        try await client.succeed(
            oldCall.id,
            with: HTTPResponse(statusCode: 200, body: Data("old".utf8))
        )
        let oldResponse = try await oldTask.value
        #expect(!(await probe.commit(oldResponse.body, generation: oldGeneration)))
        #expect(await probe.value() == newBody)
    }

    @Test
    func preCancelledRequestsNeverBecomeTransportFailures() async throws {
        let request = try makeRequest()
        let clients: [any HTTPClient] = [
            DisabledHTTPClient(),
            HarnessMockHTTPClient(),
            HarnessMockHTTPClient(defaultBehavior: .failure(.offline))
        ]

        for client in clients {
            let task = Task {
                withUnsafeCurrentTask { currentTask in
                    currentTask?.cancel()
                }
                return try await client.execute(request)
            }

            do {
                _ = try await task.value
                Issue.record("Expected pre-cancelled request to remain cancellation")
            } catch is CancellationError {
                continue
            } catch {
                Issue.record("Pre-cancellation became a transport failure")
            }
        }
    }

    @Test
    func cancellationLinearizesBeforeControlledCompletion() async throws {
        let client = HarnessMockHTTPClient()
        let request = try makeRequest()
        let task = Task {
            try await client.execute(request)
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        task.cancel()

        do {
            try await client.succeed(
                call.id,
                with: HTTPResponse(statusCode: 200)
            )
            Issue.record("Completion must not replace an earlier cancellation")
        } catch let error as HarnessHTTPControlError {
            #expect(error == .unknownCall)
        } catch {
            Issue.record("Unexpected control error after cancellation")
        }

        do {
            _ = try await task.value
            Issue.record("Expected request cancellation")
        } catch is CancellationError {
            #expect(await client.pendingCalls().isEmpty)
            let events = await client.events()
            #expect(events.contains(.cancelled(call.id)))
            #expect(!events.contains(.succeeded(call.id)))
        } catch {
            Issue.record("Cancellation changed error category")
        }
    }

    @Test
    func pendingCountWaiterHonorsPreCancellation() async {
        let client = HarnessMockHTTPClient()
        let waiter = Task {
            withUnsafeCurrentTask { currentTask in
                currentTask?.cancel()
            }
            try await client.waitForPendingCallCount(1)
        }

        do {
            try await waiter.value
            Issue.record("Expected pending-count waiter cancellation")
        } catch is CancellationError {
            #expect(await client.pendingCalls().isEmpty)
        } catch {
            Issue.record("Pending-count waiter changed error category")
        }
    }

    private func makeRequest() throws -> HTTPRequest {
        let url = try #require(URL(string: "https://fixture.invalid/harness"))
        return try HTTPRequest(method: .get, url: url)
    }
}
