import CoreGraphics

/// A one-shot navigation request. Completion releases the historical target.
struct InitialReadingRestoration<ID: Hashable> {
    private(set) var target: ID?
    private(set) var hasPositioned = false
    private(set) var permitsProgress = false
    var isActive: Bool { target != nil }

    init(target: ID) { self.target = target }

    mutating func positioned() { hasPositioned = true }

    mutating func stop(permitsProgress: Bool) {
        target = nil
        self.permitsProgress = permitsProgress
    }
}

/// Geometry from the last valid, displayed viewport, independent of initial navigation.
struct ReadingViewportAnchor<ID: Hashable> {
    let rowID: ID
    let relativeY: CGFloat
    let layoutSize: CGSize

    init(rowID: ID, rowMinY: CGFloat, offsetY: CGFloat, topInset: CGFloat, layoutSize: CGSize) {
        self.rowID = rowID
        relativeY = rowMinY - offsetY - topInset
        self.layoutSize = layoutSize
    }

    func desiredOffset(rowMinY: CGFloat, topInset: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(upper, max(lower, rowMinY - topInset - relativeY))
    }
}
