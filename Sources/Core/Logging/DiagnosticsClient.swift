enum DiagnosticCategory: String, CaseIterable, Equatable, Sendable {
    case application
    case image
    case networking
    case session
}

enum DiagnosticResultCategory: String, CaseIterable, Equatable, Sendable {
    case cancelled
    case malformed
    case offline
    case server
    case stale
    case success
    case timeout
}

struct DiagnosticOperationID: Equatable, Hashable, Sendable {
    let rawValue: String

    static let appBootstrap = DiagnosticOperationID(
        validatedRawValue: "app-bootstrap"
    )

    init?(_ rawValue: String) {
        guard Self.isSafeSymbol(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    private init(validatedRawValue: String) {
        rawValue = validatedRawValue
    }

    private static func isSafeSymbol(_ value: String) -> Bool {
        guard (1...64).contains(value.utf8.count) else {
            return false
        }
        return value.utf8.allSatisfy { byte in
            switch byte {
            case 45, 46, 48...57, 65...90, 95, 97...122:
                true
            default:
                false
            }
        }
    }
}

struct DiagnosticEvent: Equatable, Sendable {
    let category: DiagnosticCategory
    let operation: DiagnosticOperationID
    let requestID: OperationID?
    let result: DiagnosticResultCategory
    let safeCount: Int?

    init(
        category: DiagnosticCategory,
        operation: DiagnosticOperationID,
        requestID: OperationID?,
        result: DiagnosticResultCategory,
        safeCount: Int? = nil
    ) {
        self.category = category
        self.operation = operation
        self.requestID = requestID
        self.result = result
        if let safeCount, (0...1_000_000).contains(safeCount) {
            self.safeCount = safeCount
        } else {
            self.safeCount = nil
        }
    }

    var safeDescription: String {
        var fields = [
            "category=\(category.rawValue)",
            "operation=\(operation.rawValue)",
            "result=\(result.rawValue)"
        ]
        if let requestID {
            fields.append("request=\(requestID.safeDescription)")
        }
        if let safeCount {
            fields.append("count=\(safeCount)")
        }
        return fields.joined(separator: " ")
    }
}

protocol DiagnosticsClient: Sendable {
    func record(_ event: DiagnosticEvent) async
}
