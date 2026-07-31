import Testing
@testable import TiebaLite

struct DesignSystemTests {
    @Test
    func semanticTokenFamiliesAreCompleteAndOrdered() {
        #expect(SemanticColorRole.allCases.count == 8)
        #expect(TypographyRole.allCases.count == 6)
        #expect(Spacing.xSmall < Spacing.small)
        #expect(Spacing.small < Spacing.medium)
        #expect(Spacing.medium < Spacing.large)
        #expect(CornerRadius.small < CornerRadius.large)
        #expect(IconSize.small < IconSize.large)
    }

    @Test
    func motionTokensResolveThroughOneReduceMotionBoundary() {
        let cases: [(MotionToken, MotionResolution)] = [
            (Motion.instant, .none),
            (
                Motion.fast,
                .animated(duration: 0.15, curve: .easeOut)
            ),
            (
                Motion.standard,
                .animated(duration: 0.25, curve: .easeInOut)
            ),
            (
                Motion.emphasized,
                .animated(duration: 0.35, curve: .easeInOut)
            ),
            (
                Motion.interactive,
                .animated(duration: 0.30, curve: .easeOut)
            )
        ]

        for (token, expected) in cases {
            #expect(Motion.resolution(for: token, reduceMotion: true) == .none)
            #expect(
                Motion.resolution(for: token, reduceMotion: false) == expected
            )
        }
    }
}
