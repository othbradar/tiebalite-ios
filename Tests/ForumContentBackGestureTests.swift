import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct ForumContentBackGestureTests {
    @Test func boundaryChangesUseTheCurrentCallbackWithoutReplacingGateOrSystemDelegates() throws {
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.pushViewController(UIViewController(), animated: false)
        let scroll = UIScrollView()
        let bridge = PagerNavigationBack()
        let edgeDelegate = navigation.interactivePopGestureRecognizer?.delegate
        let pagerDelegate = scroll.panGestureRecognizer.delegate
        bridge.install(on: scroll, pagerPan: scroll.panGestureRecognizer, navigation: navigation, isAtBoundary: { true })
        #expect(!bridge.reservesHorizontalPaging(velocity: CGPoint(x: 100, y: 0)))
        let gate = bridge.gate
        bridge.install(on: scroll, pagerPan: scroll.panGestureRecognizer, navigation: navigation, isAtBoundary: { false })
        #expect(bridge.gate === gate)
        #expect(bridge.reservesHorizontalPaging(velocity: CGPoint(x: 100, y: 0)))
        #expect(bridge.reservesHorizontalPaging(velocity: CGPoint(x: -100, y: 0)))
        #expect(!bridge.reservesHorizontalPaging(velocity: CGPoint(x: 10, y: 100)))
        #expect(!bridge.reservesHorizontalPaging(velocity: .zero))
        #expect(navigation.interactivePopGestureRecognizer?.delegate === edgeDelegate)
        #expect(scroll.panGestureRecognizer.delegate === pagerDelegate)
        if #available(iOS 26.0, *) {
            #expect(try #require(gate).view === scroll)
            #expect(gate?.cancelsTouchesInView == false)
            let contentPop = try #require(navigation.interactiveContentPopGestureRecognizer)
            #expect(gate?.canPrevent(contentPop) == true)
            #expect(gate?.canPrevent(scroll.panGestureRecognizer) == false)
            #expect(gate?.canBePrevented(by: scroll.panGestureRecognizer) == false)
        }
        bridge.uninstall()
        #expect(bridge.gate == nil)
        #expect(gate?.view == nil && gate?.delegate == nil)
    }
}
