import Foundation

/// Runs only for the Live scene's actual background event. No timer, network,
/// content-cache eviction, credential deletion or navigation change.
enum NativeWriteBackgroundCleanup {
    private static let diagnostics = OSDiagnosticsClient()

    static func run() async {
        do {
            try await NativeWriteAccountVault.shared.enteredBackground()
        } catch {
            guard let operation = DiagnosticOperationID("native-write-state-cleanup") else { return }
            await diagnostics.record(.init(category: .session, operation: operation,
                                           requestID: nil, result: .offline))
        }
    }
}
