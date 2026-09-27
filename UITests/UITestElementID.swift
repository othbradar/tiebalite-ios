import XCTest
enum UITestElementID: String, CaseIterable {
    case componentEmpty = "design-system.empty-state"
    case componentFullPageError = "design-system.full-page-error"
    case componentFullPageErrorRetry = "design-system.full-page-error.retry"
    case componentInitialLoading = "design-system.initial-loading"
    case componentInlineError = "design-system.inline-error"
    case componentInlineErrorRetry = "design-system.inline-error.retry"
    case componentInlineLoading = "design-system.inline-loading"
    case componentPagination = "design-system.pagination-footer"
    case debugOpenGallery = "app.debug.open-component-gallery"
    case debugOpenThreadContentRenderer = "app.debug.open-thread-content-renderer-lab"
    case followedForumsRoot = "app.root.followed-forums"
    case followedForumsFirstRow = "followed-forums.row.f13001"
    case followedForumsLogin = "followed-forums.session.login"
    case followedForumsSignedOut = "followed-forums.session.signed-out"
    case galleryAppearance = "design-system.gallery.appearance"
    case galleryDynamicType = "design-system.gallery.dynamic-type"
    case galleryReduceMotion = "design-system.gallery.reduce-motion"
    case galleryRoot = "design-system.gallery"
    case interactionCandidate = "interaction.lab.candidate"
    case interactionCurrentPage = "interaction.pager.current-id"
    case interactionLabTitle = "interaction.lab.title"
    case interactionMediaChrome = "interaction.media.chrome"
    case interactionMediaClose = "interaction.media.close"
    case interactionMediaCurrent = "interaction.media.current-id"
    case interactionMediaOwner = "interaction.media.gesture-owner"
    case interactionMediaAccessibilityNext = "interaction.media.accessibility.next"
    case interactionMediaAccessibilityPrevious = "interaction.media.accessibility.previous"
    case interactionMediaFailure = "interaction.media.error.failure"
    case interactionMediaLoading = "interaction.media.loading.delayed"
    case interactionMediaOpenMultiple = "interaction.media.open.multiple"
    case interactionMediaOpenSingle = "interaction.media.open.single"
    case interactionMediaOverlayState = "interaction.media.overlay-state"
    case interactionMediaReleaseDelayed = "interaction.media.release-delayed"
    case interactionMediaRetryFailure = "interaction.media.retry.failure"
    case interactionMediaSource = "interaction.media.source-anchor"
    case interactionMediaViewer = "interaction.media.viewer"
    case interactionMediaZoom = "interaction.media.zoom-state"
    case interactionPagerArmDelete = "interaction.pager.action.arm-delete"
    case interactionPagerArmInsert = "interaction.pager.action.arm-insert"
    case interactionPagerArmRefresh = "interaction.pager.action.arm-refresh"
    case interactionPagerArmReorder =
        "interaction.pager.action.arm-reorder"
    case interactionPagerAccessibilityNext =
        "interaction.pager.accessibility.next"
    case interactionPagerAccessibilityPrevious =
        "interaction.pager.accessibility.previous"
    case interactionPagerCompletion =
        "interaction.pager.completion-count"
    case interactionPagerControllerCount =
        "interaction.pager.controller-count"
    case interactionPagerCoordinatorSequence =
        "interaction.pager.coordinator-sequence"
    case interactionPagerGeometry = "interaction.pager.geometry"
    case interactionPagerSettledProjection =
        "interaction.pager.settled-projection"
    case interactionPagerInFlightRefresh =
        "interaction.pager.in-flight-refresh"
    case interactionPagerInputMismatches =
        "interaction.pager.input-mismatches"
    case interactionPagerInputCount = "interaction.pager.input-count"
    case interactionPagerInputResolution =
        "interaction.pager.input-resolution"
    case interactionPagerInputTrace = "interaction.pager.input-trace"
    case interactionPagerLifecycle = "interaction.pager.lifecycle"
    case interactionPagerNextContentState =
        "interaction.pager.action.next-content-state"
    case interactionPagerPageP0 = "interaction.pager.page.p0"
    case interactionPagerPageP1 = "interaction.pager.page.p1"
    case interactionPagerPageP2 = "interaction.pager.page.p2"
    case interactionPagerPageP2ContentAction =
        "interaction.pager.page.p2.content-action"
    case interactionPagerPageP2ControllerSequence =
        "interaction.pager.page.p2.controller-sequence"
    case interactionPagerPageP2Generation =
        "interaction.pager.page.p2.generation"
    case interactionPagerPageP2StateBadge =
        "interaction.pager.page.p2.state-badge"
    case interactionPagerPageP2VerticalScroll =
        "interaction.pager.page.p2.vertical-scroll"
    case interactionPagerPageP3 = "interaction.pager.page.p3"
    case interactionPagerPageP3ControllerSequence =
        "interaction.pager.page.p3.controller-sequence"
    case interactionPagerPageP4 = "interaction.pager.page.p4"
    case interactionPagerPosition = "interaction.pager.position"
    case interactionPagerProjection = "interaction.pager.projection"
    case interactionPagerVerticalScrollOffset =
        "interaction.pager.vertical-scroll-offset"
    case interactionPagerRefresh = "interaction.pager.refresh-state"
    case interactionPagerReset = "interaction.pager.action.reset"
    case interactionPagerStaleRejections =
        "interaction.pager.stale-rejections"
    case interactionPagerStaleResponse =
        "interaction.pager.action.stale-response"
    case interactionPagerSettledSnapshotCount =
        "interaction.pager.settled-snapshot-count"
    case interactionPagerStateGeneration =
        "interaction.pager.state-generation"
    case interactionPagerTransition =
        "interaction.pager.transition-state"
    case interactionPagerAdjustable = "interaction.pager.adjustable"
    case interactionPagerViewportWidth =
        "interaction.pager.viewport-width"
    case interactionPagerViewportHeight =
        "interaction.pager.viewport-height"
    case interactionSectionMedia = "interaction.lab.section.media"
    case interactionSectionPager = "interaction.lab.section.pager"
    case invalidScenario = "app.launch-scenario.invalid"
    case forumHomeHeader = "forum-home.header"
    case forumHomeList = "forum-home.list"
    case forumHomeSelectedRow = "forum-home.row.t140006"
    case forumThreadReaderScreen = "thread-reader.screen.t140006"
    case layoutControlCompact = "app.harness.layout.compact"
    case layoutControlRegular = "app.harness.layout.regular"
    case layoutCompact = "app.shell.layout.compact"
    case layoutRegular = "app.shell.layout.regular"
    case mediaViewerChrome = "media-viewer.chrome"
    case mediaViewerClose = "media-viewer.close"
    case mediaViewerOpenMultiple = "thread-reader.renderer-lab.open-media-multiple"
    case mediaViewerOpenSingle = "thread-reader.renderer-lab.open-media-single"
    case mediaViewerNext = "media-viewer.next"
    case mediaViewerPager = "media-viewer.pager"
    case mediaViewerPrevious = "media-viewer.previous"
    case openForum = "app.fixture.root.open-forum"
    case openSubposts = "app.fixture.thread.open-subposts"
    case openThread = "app.fixture.forum.open-thread"
    case recommendationsFirstRow = "recommendations.row.t100001"
    case recommendationsFailure = "recommendations.state.failure"
    case recommendationsList = "recommendations.list"
    case recommendationsAvatarFailureRow = "recommendations.row.t100009"
    case recommendationsLastPageRow = "recommendations.row.t100012"
    case recommendationsLastPageThreadScreen = "thread-reader.screen.t100012"
    case recommendationsSelectedRow = "recommendations.row.t100003"
    case recommendationsRoot = "app.root.recommendations"
    case recommendationsSessionLogin = "recommendations.session.login"
    case recommendationsSessionSignedOut = "recommendations.session.signed-out"
    case routeForum = "app.route.forum"
    case searchField = "search.field"
    case searchForumResult = "search.forum.13001"
    case searchList = "search.list"
    case searchOpen = "app.open-search"
    case searchRoot = "search.root"
    case searchSubmit = "search.submit"
    case searchThreadResult = "search.thread.100003"
    case routeSubposts = "app.route.subposts"
    case routeThread = "app.route.thread"
    case personalRoot = "app.root.personal"
    case personalSettings = "personal.open-settings"
    case notificationsRoot = "app.root.notifications"
    case tabNotifications = "app.tab.notifications"
    case settingsRoot = "app.root.settings"
    case shellRoot = "app.shell.root"
    case shellScenario = "app.shell.scenario"
    case shellTitle = "app.shell.title"
    case tabFollowedForums = "app.tab.followed-forums"
    case tabRecommendations = "app.tab.recommendations"
    case tabSettings = "app.tab.settings"
    case threadContentAfterUnknown =
        "thread-reader.content.node.t91001.p92001.sfirstPost.n19"
    case threadContentExternalIntent =
        "thread-reader.renderer-lab.external-link"
    case threadContentImageDecodeFailureAction =
        "thread-reader.content.image.t91001.p92001.sfirstPost.n12.action"
    case threadContentImageDecodeFailureState =
        "thread-reader.content.image.t91001.p92001.sfirstPost.n12.state"
    case threadContentImageFailureAction =
        "thread-reader.content.image.t91001.p92001.sfirstPost.n11.action"
    case threadContentImageFailureState =
        "thread-reader.content.image.t91001.p92001.sfirstPost.n11.state"
    case threadContentImageLoadingAction =
        "thread-reader.content.image.t91001.p92001.sfirstPost.n10.action"
    case threadContentImageLoadingState =
        "thread-reader.content.image.t91001.p92001.sfirstPost.n10.state"
    case threadContentImageSuccessAction =
        "thread-reader.content.image.t91001.p92001.sfirstPost.n9.action"
    case threadContentImageSuccessState =
        "thread-reader.content.image.t91001.p92001.sfirstPost.n9.state"
    case threadContentLabAppearance =
        "thread-reader.renderer-lab.appearance"
    case threadContentLabDynamicType =
        "thread-reader.renderer-lab.dynamic-type"
    case threadContentLabReduceMotion =
        "thread-reader.renderer-lab.reduce-motion"
    case threadContentLabRoot = "thread-reader.renderer-lab"
    case threadContentInlineText =
        "thread-reader.content.node.t91001.p92001.sfirstPost.n0"
    case threadContentMediaIntent =
        "thread-reader.renderer-lab.media-route"
    case threadContentUnknown =
        "thread-reader.content.node.t91001.p92001.sfirstPost.n17"
    case threadReaderImageSecondAction =
        "thread-reader.content.image.t100003.p110003.sfirstPost.n2.action"
    case threadReaderImageSecondState =
        "thread-reader.content.image.t100003.p110003.sfirstPost.n2.state"
    case forumThreadImageAction = "thread-reader.content.image.t140006.p170006.spost.n1.action"
    case forumThreadImageState = "thread-reader.content.image.t140006.p170006.spost.n1.state"
    case forumThreadLastPagePost = "thread-reader.post.t140006.p910006.spost"
    case forumThreadLoadMore = "thread-reader.pagination.load-more.t140006"
    case forumThreadReaderScroll = "thread-reader.scroll.t140006"
    case forumThreadSubpost = "thread-reader.subpost.t140006.p160007.ssubPost"
    case threadReaderScreen = "thread-reader.screen.t100003"
    case threadReaderScroll = "thread-reader.scroll.t100003"
    case debugOpenInteractionLab = "app.debug.open-interaction-lab"
}
