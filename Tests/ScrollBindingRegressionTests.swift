import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

extension SFScrollTests {
    @MainActor @Suite(.serialized)
    struct ScrollBindingRegressionTests {
        @Test func stableContentUsesLatestActionAndNewTextIsVisible() async throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene); window.frame = scene.coordinateSpace.bounds
            let controller = UIViewController(); window.rootViewController = controller
            let table = VirtualizedTableView(frame: .init(x: 0, y: 80, width: 390, height: 600), style: .plain)
            controller.view.addSubview(table); window.makeKeyAndVisible()
            var selected = 0
            func list(text: String, callback: Int, size: CGFloat = 17, optIn: Bool = true) -> VirtualizedList<SFActionItem, SFActionView> {
                VirtualizedList(
                    items: [.init(id: 1, text: text, size: size)], backgroundColor: .systemBackground,
                    accessibilityIdentifier: "sf.binding", contentVersion: "\(text)-\(size)",
                    refreshUnchangedContent: optIn ? { old, next in
                        guard old.item == next.item else { return false }
                        old.action.perform = next.action.perform
                        return true
                    } : nil) { item in
                        SFActionView(item: item, action: SFAction { selected = callback })
                    }
            }
            let coordinator = list(text: "旧内容", callback: 1).makeCoordinator()
            defer { coordinator.dismantle(); window.isHidden = true }
            coordinator.install(on: table); coordinator.synchronize()
            try #require(await VirtualListNativeCondition.wait {
                !coordinator.isApplyingSnapshot && button(in: table)?.currentTitle == "旧内容"
            })
            ScrollWorkMetrics.start()
            coordinator.parent = list(text: "旧内容", callback: 99); coordinator.synchronize()
            let counts = ScrollWorkMetrics.stop()
            try #require(button(in: table)).sendActions(for: .touchUpInside)
            #expect(selected == 99)
            #expect(counts["cell.hostConfiguration", default: 0] == 0)
            #expect(counts["cell.actionsOnly", default: 0] > 0)
            coordinator.parent = list(text: "新内容", callback: 7, size: 26); coordinator.synchronize()
            try #require(await VirtualListNativeCondition.wait {
                button(in: table)?.currentTitle == "新内容" && button(in: table)?.titleLabel?.font.pointSize == 26
            })
            try #require(button(in: table)).sendActions(for: .touchUpInside)
            #expect(selected == 7)
            ScrollWorkMetrics.start()
            coordinator.parent = list(text: "新内容", callback: 8, size: 26, optIn: false); coordinator.synchronize()
            #expect(ScrollWorkMetrics.stop()["cell.hostConfiguration", default: 0] > 0)
            try #require(await VirtualListNativeCondition.wait { button(in: table)?.currentTitle == "新内容" })
        }
        private func button(in view: UIView) -> UIButton? {
            if let button = view as? UIButton, button.window != nil { return button }
            return view.subviews.lazy.compactMap { button(in: $0) }.first
        }
    }
}

private struct SFActionItem: Identifiable, Equatable, Sendable { let id: Int; let text: String; let size: CGFloat }
@MainActor private final class SFAction { var perform: () -> Void; init(_ perform: @escaping () -> Void) { self.perform = perform } }
private struct SFActionView: UIViewRepresentable {
    let item: SFActionItem
    let action: SFAction
    func makeUIView(context: Context) -> UIButton { UIButton(type: .system) }
    func updateUIView(_ button: UIButton, context: Context) {
        button.setTitle(item.text, for: .normal); button.titleLabel?.font = .systemFont(ofSize: item.size)
        button.removeAction(identifiedBy: .init("sf.action"), for: .touchUpInside)
        button.addAction(UIAction(identifier: .init("sf.action")) { _ in action.perform() }, for: .touchUpInside)
    }
}
