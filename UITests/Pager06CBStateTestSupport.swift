import UIKit
import XCTest

struct PagerBoundaryExpectation {
    let towardLeft: Bool
    let id: String
    let position: String
    let page: UITestElementID
    let resolvedCount: Int
}

enum Pager06CBHostGeometryAssertions {
    @MainActor
    static func requireOpaqueBoundsCoverage(
        in app: XCUIApplication
    ) -> CGRect {
        let geometry = UITestHarness.element(
            .interactionPagerGeometry,
            in: app
        )
        XCTAssertTrue(geometry.waitForExistence(timeout: 5))
        let label = geometry.label
        XCTAssertTrue(
            label.contains("Geometry: covered, opaque"),
            "Unexpected Pager geometry: \(label)"
        )
        guard let rootMarker = label.range(of: "root "),
              let boundsMarker = label.range(of: ", bounds "),
              let rootFrame = parseFrame(
                String(label[rootMarker.upperBound..<boundsMarker.lowerBound])
              ),
              let boundsFrame = parseFrame(
                String(label[boundsMarker.upperBound...])
              ) else {
            XCTFail("Unparseable Pager geometry: \(label)")
            return .zero
        }
        XCTAssertEqual(rootFrame.minX, boundsFrame.minX, accuracy: 1)
        XCTAssertEqual(rootFrame.minY, boundsFrame.minY, accuracy: 1)
        XCTAssertEqual(rootFrame.width, boundsFrame.width, accuracy: 1)
        XCTAssertEqual(rootFrame.height, boundsFrame.height, accuracy: 1)
        XCTAssertGreaterThan(boundsFrame.width, 44)
        XCTAssertGreaterThan(boundsFrame.height, 44)
        return boundsFrame
    }

    private static func parseFrame(_ value: String) -> CGRect? {
        let components = value.split(separator: " ")
        guard components.count == 2 else {
            return nil
        }
        let origin = components[0].split(separator: ",")
        let size = components[1].split(separator: "x")
        guard origin.count == 2,
              size.count == 2,
              let x = Double(origin[0]),
              let y = Double(origin[1]),
              let width = Double(size[0]),
              let height = Double(size[1]) else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

extension InteractionLabTests {
    @MainActor
    func exercise06CBBoundaryBurst(
        expectation: PagerBoundaryExpectation,
        viewport: XCUIElement,
        settledSnapshotCount: XCUIElement,
        in app: XCUIApplication
    ) {
        reset06CBPager(in: app)
        let beforeBoundary = settledSnapshotCount.label
        for _ in 0..<20 {
            if expectation.towardLeft {
                viewport.swipeLeft(velocity: .fast)
            } else {
                viewport.swipeRight(velocity: .fast)
            }
        }
        require06CBVisualSelection(
            id: expectation.id,
            position: expectation.position,
            page: expectation.page,
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerCompletion,
            equals: "Resolved: \(expectation.resolvedCount)",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerInputCount,
            equals: "Inputs: 20",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerInputResolution,
            equals: "Resolution: ended-without-transition, visual "
                + expectation.id,
            in: app
        )
        UITestHarness.requireLabelNotEqual(
            .interactionPagerSettledSnapshotCount,
            to: beforeBoundary,
            in: app
        )
        require06CBInputAudit(in: app)
        require06CBNoMagentaExposure()
        let lifecycle = UITestHarness.element(
            .interactionPagerLifecycle,
            in: app
        )
        XCTAssertTrue(
            lifecycle.label.contains("orphans 0"),
            "Unexpected settled lifecycle: \(lifecycle.label)"
        )
    }

    @MainActor
    func exercise06CBRetainedStates(
        in app: XCUIApplication,
        baselineFrame: CGRect,
        controllerLabel: String
    ) {
        let states = ["refreshing", "loading-next-page", "refresh-failure"]
        for (index, state) in states.enumerated() {
            UITestHarness.tap(.interactionPagerNextContentState, in: app)
            UITestHarness.requireLabel(
                .interactionPagerRefresh,
                equals: "State: \(state)",
                in: app
            )
            XCTAssertEqual(
                UITestHarness.element(
                    .interactionPagerPageP2ControllerSequence,
                    in: app
                ).label,
                controllerLabel
            )
            let badge = UITestHarness.element(
                .interactionPagerPageP2StateBadge,
                in: app
            )
            XCTAssertTrue(badge.waitForExistence(timeout: 5))
            UITestHarness.tap(
                .interactionPagerPageP2ContentAction,
                in: app
            )
            UITestHarness.requireLabel(
                .interactionPagerPageP2ContentAction,
                equals: "Content hits: \(index + 1)",
                in: app
            )
            require06CBPageFrame(baselineFrame, in: app)
        }
    }

    @MainActor
    func exercise06CBInitialStates(
        in app: XCUIApplication,
        baselineFrame: CGRect,
        controllerLabel: String
    ) {
        let states: [(String, UITestElementID)] = [
            ("initial-loading", .componentInitialLoading),
            ("initial-failure", .componentFullPageErrorRetry),
            ("empty", .componentEmpty)
        ]
        for (state, component) in states {
            UITestHarness.tap(.interactionPagerNextContentState, in: app)
            UITestHarness.requireLabel(
                .interactionPagerRefresh,
                equals: "State: \(state)",
                in: app
            )
            UITestHarness.requirePresent(component, in: app)
            require06CBPageFrame(baselineFrame, in: app)
        }

        UITestHarness.tap(.interactionPagerNextContentState, in: app)
        UITestHarness.requireLabel(
            .interactionPagerRefresh,
            equals: "State: loaded",
            in: app
        )
        XCTAssertEqual(
            UITestHarness.element(
                .interactionPagerPageP2ControllerSequence,
                in: app
            ).label,
            controllerLabel
        )
        require06CBPageFrame(baselineFrame, in: app)
    }

    @MainActor
    func controllerSequence(
        for pageID: String,
        in app: XCUIApplication
    ) -> String {
        let element = app.descendants(matching: .any)[
            "interaction.pager.page.\(pageID).controller-sequence"
        ]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        return element.label.replacingOccurrences(
            of: "Controller: ",
            with: ""
        )
    }

    @MainActor
    func require06CBInputAudit(in app: XCUIApplication) {
        UITestHarness.requireLabel(
            .interactionPagerInputMismatches,
            equals: "Input mismatches: 0",
            in: app
        )
        let settled = UITestHarness.element(
            .interactionPagerSettledProjection,
            in: app
        )
        XCTAssertTrue(settled.waitForExistence(timeout: 5))
        XCTAssertTrue(settled.label.contains("callbacks 0, overlaps 0"))
        XCTAssertTrue(settled.label.hasSuffix("sentinel 0"))
    }

    @MainActor
    func require06CBNoMagentaExposure() {
        let screenshot = XCUIScreen.main.screenshot()
        let magentaPixelCount = countExposurePixels(in: screenshot.image)
        if magentaPixelCount != 0 {
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Unexpected Pager magenta exposure"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertEqual(
            magentaPixelCount,
            0,
            "Pager exposed \(magentaPixelCount) magenta sentinel pixels"
        )
    }

    private func countExposurePixels(in image: UIImage) -> Int {
        guard let source = image.cgImage else {
            XCTFail("Pager screenshot had no CGImage backing")
            return -1
        }
        let width = source.width
        let height = source.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](
            repeating: 0,
            count: height * bytesPerRow
        )
        return pixels.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                        | CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                XCTFail("Could not decode Pager screenshot pixels")
                return -1
            }
            context.draw(
                source,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
            let values = buffer.bindMemory(to: UInt8.self)
            var magentaPixelCount = 0
            for offset in stride(
                from: 0,
                to: values.count,
                by: bytesPerPixel
            ) {
                let red = values[offset]
                let green = values[offset + 1]
                let blue = values[offset + 2]
                let alpha = values[offset + 3]
                if red >= 220,
                   green <= 40,
                   blue >= 220,
                   alpha >= 200 {
                    magentaPixelCount += 1
                }
            }
            return magentaPixelCount
        }
    }
}
