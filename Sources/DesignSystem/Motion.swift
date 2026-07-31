import SwiftUI

private struct MotionReductionOverrideKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var motionReductionOverride: Bool {
        get { self[MotionReductionOverrideKey.self] }
        set { self[MotionReductionOverrideKey.self] = newValue }
    }
}

enum MotionCurve: Equatable, Sendable {
    case easeInOut
    case easeOut
    case linear
}

enum MotionResolution: Equatable, Sendable {
    case animated(duration: TimeInterval, curve: MotionCurve)
    case none
}

struct MotionToken: Equatable, Sendable {
    fileprivate let duration: TimeInterval
    fileprivate let curve: MotionCurve
}

enum Motion {
    static let instant = MotionToken(duration: 0, curve: .linear)
    static let fast = MotionToken(duration: 0.15, curve: .easeOut)
    static let standard = MotionToken(duration: 0.25, curve: .easeInOut)
    static let emphasized = MotionToken(duration: 0.35, curve: .easeInOut)
    static let interactive = MotionToken(duration: 0.30, curve: .easeOut)

    static func resolution(
        for token: MotionToken,
        reduceMotion: Bool
    ) -> MotionResolution {
        guard !reduceMotion, token.duration > 0 else {
            return .none
        }
        return .animated(duration: token.duration, curve: token.curve)
    }

    static func animation(
        for token: MotionToken,
        reduceMotion: Bool
    ) -> Animation? {
        switch resolution(for: token, reduceMotion: reduceMotion) {
        case .none:
            nil
        case let .animated(duration, curve):
            switch curve {
            case .easeInOut:
                .easeInOut(duration: duration)
            case .easeOut:
                .easeOut(duration: duration)
            case .linear:
                .linear(duration: duration)
            }
        }
    }
}

private struct MotionAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.motionReductionOverride) private var reductionOverride

    let token: MotionToken
    let value: Value

    func body(content: Content) -> some View {
        content.animation(
            Motion.animation(
                for: token,
                reduceMotion: reduceMotion || reductionOverride
            ),
            value: value
        )
    }
}

extension View {
    func motionAnimation<Value: Equatable>(
        _ token: MotionToken,
        value: Value
    ) -> some View {
        modifier(MotionAnimationModifier(token: token, value: value))
    }
}
