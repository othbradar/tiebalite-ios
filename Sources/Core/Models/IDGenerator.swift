struct OperationID: Hashable, Sendable {
    let sequence: UInt64

    var safeDescription: String {
        "operation-\(sequence)"
    }
}

protocol IDGenerator: Sendable {
    func next() async throws -> OperationID
}

actor MonotonicIDGenerator: IDGenerator {
    private var nextSequence: UInt64

    init(startingAt firstSequence: UInt64 = 1) {
        nextSequence = firstSequence
    }

    func next() async throws -> OperationID {
        let identifier = OperationID(sequence: nextSequence)
        nextSequence += 1
        return identifier
    }
}
