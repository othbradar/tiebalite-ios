# Interaction inventory

Repository: /Users/othbradar/PycharmProjects/tiebalite重构
Commit: 4005387738f8c7425e93fde82b042cb589c98699

## Animations and transitions

Sources/DesignSystem/Motion.swift:75:        content.animation(
Sources/DesignSystem/Motion.swift:76:            Motion.animation(

## Gestures

Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:79:        private var singleTapRecognizer: UITapGestureRecognizer?
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:80:        private var doubleTapRecognizer: UITapGestureRecognizer?
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:90:            let singleTap = UITapGestureRecognizer(
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:96:            let doubleTap = UITapGestureRecognizer(
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:178:        private func doubleTapped(_ recognizer: UITapGestureRecognizer) {

## Presentation and overlays

App/AppShellView.swift:19:        .safeAreaInset(edge: .top, spacing: 0) {
App/AppShellView.swift:43:                    .background(SemanticColor.surface)
App/AppShellView.swift:46:        .background(SemanticColor.background)
App/AppShellView.swift:77:        .safeAreaInset(edge: .bottom, spacing: 0) {
App/AppShellView.swift:164:            .background(SemanticColor.surface)
App/DebugComponentGalleryView.swift:71:        .background(SemanticColor.background)
App/DebugInteractionLabView.swift:59:        .background(SemanticColor.background)
App/DebugMediaPageView.swift:123:        .fullScreenCover(item: $presentation) { presentation in
App/DebugMediaPageView.swift:163:            Color.black.ignoresSafeArea()
App/DebugMediaPageView.swift:214:            .background(Color.black.opacity(0.78))
App/DebugMediaPageView.swift:261:            .background(Color.black.opacity(0.78))
App/FixturePlaceholderViews.swift:30:        .background(SemanticColor.background)
App/FixturePlaceholderViews.swift:73:        .background(SemanticColor.background)
App/FixturePlaceholderViews.swift:112:        .background(SemanticColor.background)
Sources/DesignSystem/StateComponents.swift:22:        .background(SemanticColor.background)
Sources/DesignSystem/StateComponents.swift:103:        .background(SemanticColor.background)
Sources/DesignSystem/StateComponents.swift:127:        .background(SemanticColor.surface)

## Scrolling and paging

App/AppShellView.swift:55:        TabView(selection: selectedTabBinding) {
App/AppShellView.swift:175:            List {
App/DebugPagerLabView.swift:56:            Text("Candidate: UIPageViewController")
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:57:    ) -> UIPageViewController {
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:58:        let controller = UIPageViewController(
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:68:        _ pageViewController: UIPageViewController,
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:76:        _ pageViewController: UIPageViewController,
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:85:        UIPageViewControllerDataSource,
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:86:        UIPageViewControllerDelegate {
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:93:        private weak var installedController: UIPageViewController?
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:112:        func install(on controller: UIPageViewController) {
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:120:        func synchronize(_ controller: UIPageViewController) {
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:146:        func dismantle(_ controller: UIPageViewController) {
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:156:            _ pageViewController: UIPageViewController,
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:166:            _ pageViewController: UIPageViewController,
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:176:            _ pageViewController: UIPageViewController,
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:190:            _ pageViewController: UIPageViewController,
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:261:            in controller: UIPageViewController,
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:291:        ) -> UIPageViewController.NavigationDirection {
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:343:            in controller: UIPageViewController
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:345:            for case let scrollView as UIScrollView
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:50:        let scrollView = DebugZoomScrollView()
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:75:    final class Coordinator: NSObject, UIScrollViewDelegate {
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:123:            in scrollView: UIScrollView
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:128:        func scrollViewDidZoom(_ scrollView: UIScrollView) {
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:136:        func scrollViewDidScroll(_ scrollView: UIScrollView) {
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:144:            _ scrollView: UIScrollView,
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:155:        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:214:final class DebugZoomScrollView: UIScrollView {

## Navigation

App/AppShellView.swift:62:            NavigationStack(path: settingsPathBinding) {
App/AppShellView.swift:70:                .navigationDestination(for: SettingsRoute.self) { route in
App/AppShellView.swift:105:        NavigationStack(path: pathBinding(for: root)) {
App/AppShellView.swift:112:            .navigationDestination(for: RouteIdentity.self) { route in
App/AppShellView.swift:174:        NavigationSplitView {
App/AppShellView.swift:216:            NavigationStack {
App/AppShellView.swift:233:            NavigationStack {
App/AppShellView.swift:246:        NavigationStack {
App/AppShellView.swift:265:            NavigationStack(path: detailTailBinding) {
App/AppShellView.swift:271:                .navigationDestination(for: RouteIdentity.self) { route in

## Identity and lifecycle

App/AppShellView.swift:135:                ForEach(AppTab.allCases) { tab in
App/AppShellView.swift:176:                ForEach(AppTab.allCases) { tab in
App/DebugInteractionLabView.swift:40:                ForEach(Section.allCases) { section in
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:67:    func updateUIViewController(
Sources/InteractionKit/InteractionLab/DebugPagerContainer.swift:75:    static func dismantleUIViewController(
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:56:    func updateUIView(
Sources/InteractionKit/InteractionLab/DebugZoomImageView.swift:67:    static func dismantleUIView(
