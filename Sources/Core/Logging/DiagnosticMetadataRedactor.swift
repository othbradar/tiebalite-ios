struct RedactedDiagnosticMetadata: Equatable, Sendable {
    let values: [String: String]

    var safeDescription: String {
        values.keys.sorted().map { key in
            "\(key)=\(values[key, default: ""])"
        }
        .joined(separator: " ")
    }
}

struct DiagnosticMetadataRedactor: Sendable {
    func redact(_ rawValues: [String: String]) -> RedactedDiagnosticMetadata {
        var safeValues: [String: String] = [:]

        for (key, value) in rawValues {
            switch key.lowercased() {
            case "category":
                if DiagnosticCategory.allCases.map(\.rawValue).contains(value) {
                    safeValues["category"] = value
                }
            case "operation":
                if let operation = DiagnosticOperationID(value) {
                    safeValues["operation"] = operation.rawValue
                }
            case "result":
                if DiagnosticResultCategory.allCases.map(\.rawValue).contains(value) {
                    safeValues["result"] = value
                }
            case "count":
                if let count = Int(value), (0...1_000_000).contains(count) {
                    safeValues["count"] = String(count)
                }
            default:
                continue
            }
        }

        return RedactedDiagnosticMetadata(values: safeValues)
    }
}
