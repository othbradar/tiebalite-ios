import SwiftUI

/// Owns one business binding per physical cell. Compatible configurations carry
/// an immutable binding so UIKit's first sizing pass sees the current row.
/// A generation belongs to one binding, including A → B → A.
@MainActor
final class VirtualListCellContent<Content: View> {
    struct Binding {
        let generation: UInt64
        let rowID: AnyHashable
        let content: Content
    }

    private(set) var binding: Binding?
    private var generation: UInt64 = 0

    func bind(rowID: AnyHashable, content: Content) -> Binding {
        if binding?.rowID != rowID { generation &+= 1 }
        let next = Binding(generation: generation, rowID: rowID, content: content)
        binding = next
        return next
    }

    func unbind() {
        binding = nil
    }
}

struct VirtualListCellRoot<Content: View>: View {
    let binding: VirtualListCellContent<Content>.Binding

    var body: some View {
        binding.content.id(binding.generation)
    }
}
