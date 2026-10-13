import Foundation
import Testing

struct AppOrientationTests {
    @Test
    func installedAppDeclaresEveryIPadOrientationWithoutFullScreenRestriction() throws {
        // iPadOS uses the installed bundle's declaration for scene compatibility.
        // A controller's default mask and XCTest-forced rotation alone do not cover it.
        let orientations = try #require(
            Bundle.main.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations~ipad") as? [String]
        )
        #expect(Set(orientations) == [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight"
        ])
        #expect(Bundle.main.object(forInfoDictionaryKey: "UIRequiresFullScreen") as? Bool != true)
    }
}
