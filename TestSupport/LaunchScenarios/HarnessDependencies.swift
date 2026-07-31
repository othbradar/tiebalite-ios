import Foundation

#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
actor HarnessFixtureSessionProvider: SessionProviding {
    private var currentSnapshot: SessionSnapshot

    init(snapshot: SessionSnapshot) {
        currentSnapshot = snapshot
    }

    func snapshot() async -> SessionSnapshot {
        currentSnapshot
    }

    func setSnapshot(_ snapshot: SessionSnapshot) {
        currentSnapshot = snapshot
    }
}

actor HarnessFixtureImageLoader: ImageLoading {
    private let fixtures: [ImageRequest: ImagePayload]

    init(fixtures: [ImageRequest: ImagePayload]) {
        self.fixtures = fixtures
    }

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        try Task.checkCancellation()
        guard let payload = fixtures[request] else {
            throw ImageLoadingError.missingFixture
        }
        return payload
    }
}

actor HarnessInMemoryDataCache: DataCaching {
    private var storage: [CacheKey: Data] = [:]

    func data(for key: CacheKey) async -> Data? {
        storage[key]
    }

    func store(_ data: Data, for key: CacheKey) async {
        storage[key] = data
    }
}

actor HarnessRecordingDiagnosticsClient: DiagnosticsClient {
    private var recordedEvents: [DiagnosticEvent] = []

    func record(_ event: DiagnosticEvent) async {
        recordedEvents.append(event)
    }

    func events() -> [DiagnosticEvent] {
        recordedEvents
    }
}
#endif
