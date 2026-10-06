import SwiftUI

/// Hollow contours drawn from the user's official Tieba screenshot (2026-10-06).
struct TiebaShareIcon: View {
    var body: some View {
        TiebaShareOutline()
            .stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            .frame(width: 18, height: 18)
            .accessibilityLabel("分享")
    }
}

struct TiebaReplyIcon: View {
    var body: some View {
        TiebaReplyOutline()
            .stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            .frame(width: 18, height: 18)
            .accessibilityLabel("回复")
    }
}

private struct TiebaShareOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 9.5, y: 3.2))
        path.addCurve(to: CGPoint(x: 2.8, y: 12),
                      control1: CGPoint(x: 4.3, y: 3.2), control2: CGPoint(x: 2.8, y: 5.8))
        path.addCurve(to: CGPoint(x: 11.5, y: 21.2),
                      control1: CGPoint(x: 2.8, y: 19.3), control2: CGPoint(x: 4.3, y: 21.2))
        path.addCurve(to: CGPoint(x: 21.2, y: 10.5),
                      control1: CGPoint(x: 19.1, y: 21.2), control2: CGPoint(x: 21.2, y: 20))
        path.move(to: CGPoint(x: 10.8, y: 13.1))
        path.addCurve(to: CGPoint(x: 21, y: 4.2),
                      control1: CGPoint(x: 14, y: 8.8), control2: CGPoint(x: 17, y: 5.3))
        path.move(to: CGPoint(x: 16, y: 2.4))
        path.addQuadCurve(to: CGPoint(x: 21, y: 4.2), control: CGPoint(x: 19.2, y: 2.2))
        path.addQuadCurve(to: CGPoint(x: 19.8, y: 8.3), control: CGPoint(x: 20.9, y: 6.3))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

private struct TiebaReplyOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 12, y: 2.7))
        path.addCurve(to: CGPoint(x: 2.6, y: 10.4),
                      control1: CGPoint(x: 5.3, y: 2.7), control2: CGPoint(x: 2.6, y: 4.4))
        path.addCurve(to: CGPoint(x: 8.8, y: 19.6),
                      control1: CGPoint(x: 2.6, y: 16), control2: CGPoint(x: 4.5, y: 18.6))
        path.addLine(to: CGPoint(x: 11.3, y: 22))
        path.addQuadCurve(to: CGPoint(x: 13, y: 21.9), control: CGPoint(x: 12.2, y: 22.8))
        path.addLine(to: CGPoint(x: 15, y: 19.8))
        path.addCurve(to: CGPoint(x: 21.6, y: 11),
                      control1: CGPoint(x: 19.2, y: 19.4), control2: CGPoint(x: 21.6, y: 16.7))
        path.addCurve(to: CGPoint(x: 12, y: 2.7),
                      control1: CGPoint(x: 21.6, y: 5.1), control2: CGPoint(x: 18.5, y: 2.7))
        path.closeSubpath()
        path.move(to: CGPoint(x: 8, y: 9.1))
        path.addCurve(to: CGPoint(x: 16, y: 9.1),
                      control1: CGPoint(x: 10.3, y: 10.9), control2: CGPoint(x: 13.7, y: 10.9))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}
