import Foundation
import Testing
@testable import TiebaLite

struct DiagnosticsTests {
    @Test
    func redactorKeepsOnlyTypedSafeMetadata() {
        let secretKeyFragments = [
            ["coo", "kie"].joined(),
            ["author", "ization"].joined(),
            ["to", "ken"].joined(),
            ["bd", "uss"].joined(),
            ["st", "oken"].joined(),
            ["pass", "word"].joined(),
            ["device", "id"].joined(separator: "_")
        ]
        let canary = ["private", "fixture", "value"].joined(separator: "-")
        var raw = [
            "category": "networking",
            "operation": "fixture-load",
            "result": "success",
            "count": "2",
            "url": "https://fixture.invalid/private",
            "error": "raw failure text"
        ]
        for key in secretKeyFragments {
            raw[key] = canary
        }

        let metadata = DiagnosticMetadataRedactor().redact(raw)
        #expect(metadata.values == [
            "category": "networking",
            "count": "2",
            "operation": "fixture-load",
            "result": "success"
        ])
        #expect(!metadata.safeDescription.contains(canary))
        #expect(!metadata.safeDescription.contains("https://"))
    }

    @Test
    func recorderObservesOnlyTypedDiagnosticEvents() async {
        let recorder = HarnessRecordingDiagnosticsClient()
        let event = DiagnosticEvent(
            category: .application,
            operation: .appBootstrap,
            requestID: OperationID(sequence: 1),
            result: .success,
            safeCount: 1
        )

        await recorder.record(event)
        #expect(await recorder.events() == [event])
        #expect(!event.safeDescription.contains("://"))
    }
}
