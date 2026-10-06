import SwiftUI

/// Simple hollow outline matching the user's official Tieba reference (2026-10-06).
struct TiebaLikeIcon: View {
    var body: some View {
        TiebaLikeOutline()
            .stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            .frame(width: 18, height: 18)
            .accessibilityLabel("点赞")
    }
}

private struct TiebaLikeOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 7.2, y: 10.1))
        path.addCurve(to: CGPoint(x: 10, y: 6.7),
                      control1: CGPoint(x: 8.9, y: 9.2), control2: CGPoint(x: 10, y: 8))
        path.addCurve(to: CGPoint(x: 10.9, y: 2.3),
                      control1: CGPoint(x: 10.2, y: 5.2), control2: CGPoint(x: 10.1, y: 2.6))
        path.addCurve(to: CGPoint(x: 13.8, y: 2.2),
                      control1: CGPoint(x: 11.5, y: 1.5), control2: CGPoint(x: 13, y: 1.5))
        path.addCurve(to: CGPoint(x: 14.8, y: 5.1),
                      control1: CGPoint(x: 14.6, y: 2.9), control2: CGPoint(x: 14.9, y: 4.1))
        path.addCurve(to: CGPoint(x: 14.4, y: 8.2),
                      control1: CGPoint(x: 14.8, y: 6.2), control2: CGPoint(x: 14.6, y: 7.3))
        path.addCurve(to: CGPoint(x: 18.6, y: 8.6),
                      control1: CGPoint(x: 15.7, y: 8.3), control2: CGPoint(x: 17.4, y: 8.2))
        path.addCurve(to: CGPoint(x: 22, y: 12),
                      control1: CGPoint(x: 20.8, y: 9), control2: CGPoint(x: 22, y: 10))
        path.addCurve(to: CGPoint(x: 21, y: 18.4),
                      control1: CGPoint(x: 22, y: 14.4), control2: CGPoint(x: 21.8, y: 16.7))
        path.addCurve(to: CGPoint(x: 16.8, y: 22),
                      control1: CGPoint(x: 20.1, y: 20.8), control2: CGPoint(x: 18.7, y: 22))
        path.addLine(to: CGPoint(x: 6, y: 22))
        path.addCurve(to: CGPoint(x: 2.9, y: 19.8),
                      control1: CGPoint(x: 3.5, y: 22), control2: CGPoint(x: 2.9, y: 21.4))
        path.addLine(to: CGPoint(x: 2.9, y: 12.5))
        path.addCurve(to: CGPoint(x: 5, y: 10.1),
                      control1: CGPoint(x: 2.9, y: 10.6), control2: CGPoint(x: 3.7, y: 10.1))
        path.closeSubpath()
        path.move(to: CGPoint(x: 7.2, y: 10.1))
        path.addLine(to: CGPoint(x: 7.2, y: 22))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}
