import OSLog

actor OSDiagnosticsClient: DiagnosticsClient {
    private let logger = Logger(
        subsystem: "dev.local.tiebaliteios",
        category: "diagnostics"
    )

    func record(_ event: DiagnosticEvent) async {
        logger.info("\(event.safeDescription, privacy: .public)")
    }
}
