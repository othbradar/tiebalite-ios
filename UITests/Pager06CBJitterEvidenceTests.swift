import XCTest

extension InteractionLabTests {
    @MainActor
    func testPagerVerticalScrollHorizontalJitterDoesNotChangePage() throws {
        let app = launch06CBPagerLab()
        let page = UITestHarness.element(
            .interactionPagerPageP2,
            in: app
        )
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        let offset = UITestHarness.element(
            .interactionPagerVerticalScrollOffset,
            in: app
        )
        XCTAssertTrue(offset.waitForExistence(timeout: 5))
        let initialOffset = offset.label
        let initialController = controllerSequence(for: "p2", in: app)

        for attempt in 0..<5 {
            dragVerticalScrollWithHorizontalJitter(
                page,
                upward: attempt.isMultiple(of: 2)
            )
            UITestHarness.requireLabel(
                .interactionCurrentPage,
                equals: "Current ID: p2",
                in: app
            )
            UITestHarness.requireLabel(
                .interactionPagerPosition,
                equals: "Position: 3/5",
                in: app
            )
            if attempt == 0 {
                requireVerticalOffsetChange(
                    from: initialOffset,
                    in: offset
                )
            }
        }

        UITestHarness.requireLabel(
            .interactionPagerCompletion,
            equals: "Resolved: 0",
            in: app
        )
        require06CBVisualSelection(
            id: "p2",
            position: "3/5",
            page: .interactionPagerPageP2,
            in: app
        )
        XCTAssertEqual(
            controllerSequence(for: "p2", in: app),
            initialController
        )
        require06CBInputAudit(in: app)
    }

    @MainActor
    private func dragVerticalScrollWithHorizontalJitter(
        _ page: XCUIElement,
        upward: Bool
    ) {
        let start = page.coordinate(
            withNormalizedOffset: CGVector(
                dx: upward ? 0.43 : 0.57,
                dy: upward ? 0.78 : 0.22
            )
        )
        let end = page.coordinate(
            withNormalizedOffset: CGVector(
                dx: upward ? 0.57 : 0.43,
                dy: upward ? 0.22 : 0.78
            )
        )
        start.press(
            forDuration: 0.10,
            thenDragTo: end,
            withVelocity: .fast,
            thenHoldForDuration: 0
        )
    }

    @MainActor
    private func requireVerticalOffsetChange(
        from initialOffset: String,
        in offset: XCUIElement
    ) {
        let offsetChanged = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "label != %@",
                initialOffset
            ),
            object: offset
        )
        let observedLabel = offset.label
        XCTAssertEqual(
            XCTWaiter.wait(for: [offsetChanged], timeout: 5),
            .completed,
            "Vertical fixture did not scroll: \(observedLabel)"
        )
    }
}
