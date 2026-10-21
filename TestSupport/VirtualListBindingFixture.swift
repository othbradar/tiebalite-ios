#if TEST_SUPPORT
import SwiftUI
@testable import TiebaLite
import UIKit

struct VirtualListBindingItem: Identifiable, Equatable, Sendable {
    let id: Int
    var title: String
    var height: CGFloat = 72
    var fontSize: CGFloat = 14
}

@MainActor
final class VirtualListBindingLoader {
    struct Reply { let serial: Int; let text: String }
    private struct Request {
        let id: Int
        let continuation: CheckedContinuation<Reply, Never>
    }
    private var nextSerial = 0
    private var pending: [Int: Request] = [:]
    private(set) var applied: Set<Int> = []
    private(set) var actions: [Int] = []
    private(set) var starts: [Int: [Int]] = [:]

    func value(for id: Int) async -> Reply {
        nextSerial += 1
        let serial = nextSerial
        starts[id, default: []].append(serial)
        // Deliberately ignores cancellation to exercise late, non-cooperative work.
        return await withCheckedContinuation { pending[serial] = Request(id: id, continuation: $0) }
    }
    func didApply(_ reply: Reply) { applied.insert(reply.serial) }
    func tap(_ id: Int) { actions.append(id) }
    func finish(serial: Int, text: String) {
        pending.removeValue(forKey: serial)?.continuation.resume(returning: Reply(serial: serial, text: text))
    }
    @discardableResult
    func finish(id: Int, text: String) -> Set<Int> {
        let serials = Set(pending.filter { $0.value.id == id }.keys)
        for serial in serials { finish(serial: serial, text: text) }
        return serials
    }
    func finishAll() {
        for serial in Array(pending.keys) { finish(serial: serial, text: "finished") }
    }
}

struct VirtualListBindingRow: View {
    let item: VirtualListBindingItem
    let loader: VirtualListBindingLoader
    @State private var text: String

    init(item: VirtualListBindingItem, loader: VirtualListBindingLoader) {
        self.item = item
        self.loader = loader
        _text = State(initialValue: "\(item.title)-pending")
    }
    var body: some View {
        VirtualListBindingNativeRow(text: text, item: item, onTap: { loader.tap(item.id) })
            .frame(maxWidth: .infinity).frame(height: item.height)
            .task(id: item.id) {
                let reply = await loader.value(for: item.id)
                text = reply.text
                loader.didApply(reply)
            }
    }
}

private struct VirtualListBindingNativeRow: UIViewRepresentable {
    let text: String
    let item: VirtualListBindingItem
    let onTap: () -> Void

    func makeUIView(context: Context) -> UIStackView {
        let label = UILabel()
        let button = UIButton(type: .system)
        let stack = UIStackView(arrangedSubviews: [label, button])
        stack.axis = .vertical
        return stack
    }
    func updateUIView(_ view: UIStackView, context: Context) {
        guard let label = view.arrangedSubviews.first as? UILabel,
              let button = view.arrangedSubviews.last as? UIButton else { return }
        label.text = text
        label.font = .systemFont(ofSize: item.fontSize)
        button.setTitle(item.title, for: .normal)
        button.removeAction(identifiedBy: .init("binding.action"), for: .touchUpInside)
        button.addAction(UIAction(identifier: .init("binding.action")) { _ in onTap() }, for: .touchUpInside)
    }
}
#endif

#if TEST_SUPPORT
@MainActor
final class VirtualListBindingFixture {
    let loader = VirtualListBindingLoader()
    let window: UIWindow
    let table: VirtualizedTableView
    let coordinator: VirtualizedList<VirtualListBindingItem, VirtualListBindingRow>.Coordinator

    init(scene: UIWindowScene) {
        window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let controller = UIViewController()
        window.rootViewController = controller
        table = VirtualizedTableView(frame: CGRect(x: 0, y: 80, width: 390, height: 180), style: .plain)
        table.contentInsetAdjustmentBehavior = .never
        table.separatorStyle = .none
        controller.view.addSubview(table)
        let loader = loader
        let list = VirtualizedList(items: (1...40).map { VirtualListBindingItem(id: $0, title: "row-\($0)") },
                                   backgroundColor: .systemBackground, accessibilityIdentifier: "binding.fixture") {
            VirtualListBindingRow(item: $0, loader: loader)
        }
        coordinator = list.makeCoordinator()
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        window.layoutIfNeeded()
        table.layoutIfNeeded()
    }
    func close() {
        coordinator.dismantle()
        loader.finishAll()
        window.isHidden = true
    }
    func texts(in view: UIView) -> [String] { virtualListVisibleLabels(in: view).compactMap(\.text) }
    func waitForText(_ text: String, in view: UIView? = nil) async -> Bool {
        await VirtualListNativeCondition.wait { self.texts(in: view ?? self.table).contains(text) }
    }
    func button(in view: UIView) -> UIButton? {
        if let button = view as? UIButton { return button }
        return view.subviews.lazy.compactMap { self.button(in: $0) }.first
    }
}
#endif
