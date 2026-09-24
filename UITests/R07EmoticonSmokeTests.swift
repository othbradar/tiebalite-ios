import XCTest

final class R07EmoticonSmokeTests: XCTestCase {
    @MainActor
    func testLinkComparisonSingleActivations() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(.debugOpenThreadContentRenderer, in: app)
        UITestHarness.tap(.debugOpenThreadContentRenderer, in: app)
        app.buttons["r07.emoticons.open"].tap()
        app.buttons["r07.link.open"].tap()
        for sample in 0..<3 {
            let text = app.textViews["r07.link.sample.\(sample)"]
            XCTAssertTrue(text.waitForExistence(timeout: 5))
            let link = text.links.firstMatch
            link.tap()
            requireLabel(app.staticTexts["r07.link.count.\(sample)"], equals: "激活 1 次")
            XCTAssertEqual(app.staticTexts["r07.link.last-intent"].label, "t70007.p\(10 + sample).spost.n2 | https://fixture.invalid/r07")
        }
        let list = app.tables["r07.link.list"]
        let start = app.textViews["r07.link.sample.2"].links.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
        XCTAssertEqual(app.staticTexts["r07.link.count.2"].label, "激活 1 次")
        let bottom = app.textViews["r07.link.sample.13"]
        for _ in 0..<8 where !bottom.isHittable { list.swipeUp() }
        XCTAssertTrue(bottom.isHittable)
        XCTAssertFalse(app.textViews["r07.link.sample.0"].isHittable)
        bottom.links.firstMatch.tap()
        requireLabel(app.staticTexts["r07.link.count.13"], equals: "激活 1 次")
        XCTAssertEqual(app.staticTexts["r07.link.last-intent"].label, "t70007.p23.spost.n2 | https://fixture.invalid/r07/row23")
        let top = app.textViews["r07.link.sample.0"]
        for _ in 0..<8 where !top.isHittable { list.swipeDown() }
        XCTAssertTrue(top.isHittable)
        top.links.firstMatch.tap()
        requireLabel(app.staticTexts["r07.link.count.0"], equals: "激活 2 次")
        XCTAssertEqual(app.staticTexts["r07.link.last-intent"].label, "t70007.p10.spost.n2 | https://fixture.invalid/r07")
        XCTAssertEqual(app.staticTexts["r07.link.count.1"].label, "激活 1 次")
        XCTAssertEqual(app.staticTexts["r07.link.count.2"].label, "激活 1 次")
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R07 ABC single activations")
    }

    @MainActor
    func testLongPressCopyPreservesEmoticonAlternativeWithoutActivation() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(.debugOpenThreadContentRenderer, in: app)
        UITestHarness.tap(.debugOpenThreadContentRenderer, in: app)
        app.buttons["r07.emoticons.open"].tap()
        app.buttons["r07.link.open"].tap()
        let sample = app.textViews["r07.link.sample.1"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        let plainWidth = sample.links.firstMatch.frame.minX - sample.frame.minX
        sample.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: plainWidth * 0.55, dy: sample.frame.height / 2)).press(forDuration: 1.0)
        let leading = app.otherElements["com.apple.text.grabber.leading"]
        let trailing = app.otherElements["com.apple.text.grabber.trailing"]
        XCTAssertTrue(leading.waitForExistence(timeout: 3))
        leading.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: sample.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)))
        trailing.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: sample.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)))
        let copy = app.menuItems.matching(NSPredicate(format: "label == 'Copy' OR label == '拷贝' OR label == '复制'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 3))
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R07 native selection and copy menu")
        copy.tap()
        let pasteField = app.textFields["r07.link.paste"]
        pasteField.press(forDuration: 1.0)
        let paste = app.menuItems.matching(NSPredicate(format: "label == 'Paste' OR label == '粘贴'")).firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: 3), app.debugDescription)
        paste.tap()
        XCTAssertEqual(pasteField.value as? String, "#滑稽 中文 测试链接 @样本用户")
        XCTAssertEqual(app.staticTexts["r07.link.count.1"].label, "激活 0 次")
        XCTAssertEqual(app.staticTexts["r07.link.last-intent"].label, "尚未激活")
    }

    @MainActor
    func testOfficialInlineEmoticonsWrapAtLargeSizeAndDarkAppearance() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(.debugOpenThreadContentRenderer, in: app)
        UITestHarness.tap(.debugOpenThreadContentRenderer, in: app)
        let entry = app.buttons["r07.emoticons.open"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        let sample = app.textViews["thread-reader.content.node.t70007.p2.spost.n0"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        XCTAssertTrue(sample.label.contains("滑稽表情"))
        XCTAssertTrue(sample.label.contains("哈哈表情"))
        XCTAssertTrue(sample.label.contains("捂嘴笑表情"))
        XCTAssertTrue(sample.label.contains("微微一笑表情"))
        XCTAssertTrue(sample.label.contains("吃瓜表情"))
        XCTAssertTrue(sample.label.contains("鼠2表情"))
        let normalHeight = sample.frame.height
        let unknown = app.textViews["thread-reader.content.node.t70007.p4.spost.n0"]
        XCTAssertTrue(unknown.label.contains("#未知表情 #话题 #滑稽话题 #滑稽# #(未收录)"))
        let mixed = app.textViews["thread-reader.content.node.t70007.p3.spost.n0"]
        XCTAssertTrue(mixed.label.contains("之前 滑稽表情 测试链接 @样本用户 之后"))
        let link = mixed.links.firstMatch
        XCTAssertTrue(link.exists)
        link.tap()
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R07 original single link tap")
        requireLabel(app.staticTexts["r07.link-result"], equals: "链接意图已收到")
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R07 normal official inline emoticons")
        app.switches["r07.large"].tap()
        XCTAssertGreaterThan(sample.frame.height, normalHeight)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R07 large official inline emoticons")
        app.switches["r07.dark"].tap()
        XCTAssertTrue(sample.label.contains("滑稽表情"))
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R07 dark large official inline emoticons")
    }
    @MainActor
    private func requireLabel(_ element: XCUIElement, equals label: String, file: StaticString = #filePath, line: UInt = #line) {
        let change = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [change], timeout: 5), .completed, file: file, line: line)
        XCTAssertEqual(element.label, label, file: file, line: line)
    }

}
