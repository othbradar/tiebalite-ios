import SwiftUI
import UIKit

@MainActor
struct MediaViewer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.motionReductionOverride) private var reductionOverride

    let presentation: MediaViewerPresentation
    let imageLoader: any ImageLoading
    let close: () -> Void

    @State private var highDefinitionByID: [String: UInt64] = [:]
    @State private var qualityByID: [String: MediaViewerQualityStatus] = [:]
    @State private var viewportDiagnosticsByID: [String: String] = [:]
    @State private var imageDiagnosticsByID: [String: String] = [:]
    @State private var currentID: String?
    @State private var externalSelectionGeneration: UInt64 = 0
    @State private var chromeVisible = true
    @State private var capabilityByID: [String: MediaPageCapability] = [:]
    @State private var zoomScaleByID: [String: Double] = [:]
    @State private var resetGenerationByID: [String: UInt64] = [:]
    @State private var transitionSourceID: String?
    @State private var ownershipController =
        MediaGestureOwnershipController<String>(allowsZoomedPaging: false)
    @State private var isClosing = false
    @State private var exportMenuRequest: ImageExportRequest?
    @State private var presentsExportMenu = false
    @State private var exportStore: MediaExportStore?

    init(
        presentation: MediaViewerPresentation,
        imageLoader: any ImageLoading,
        exportStore: MediaExportStore? = nil,
        close: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.imageLoader = imageLoader
        self.close = close
        _currentID = State(initialValue: presentation.initialMediaID)
        _exportStore = State(initialValue: exportStore)
    }

    var body: some View {
        ZStack {
            SemanticColor.mediaBackground
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            PagerContainer(
                pageIDs: presentation.items.map(\.id),
                selection: $currentID,
                backgroundColor: .black,
                reduceMotion: reduceMotion || reductionOverride,
                pagingEnabled: presentation.items.count > 1,
                mediaGestureOwnership: ownershipController,
                externalSelectionGeneration: $externalSelectionGeneration,
                onEvent: handlePagerEvent
            ) { mediaID in
                mediaPage(for: mediaID)
            }
            .accessibilityLabel("图片查看器")
            .accessibilityValue("\(positionText)，\(zoomText)")
            .accessibilityAdjustableAction(moveAccessibility)
            .accessibilityIdentifier(MediaViewerAccessibilityID.pager)
            .accessibilityAction(.escape, closeViewer)

            if chromeVisible {
                chrome
            }
        }
        .background(SemanticColor.mediaBackground)
        .background {
            if let exportStore {
                ImageFileSharePresenter(file: exportStore.shareFile, began: exportStore.shareDidPresent,
                                        completion: exportStore.shareFinished)
            }
        }
        .confirmationDialog("图片操作", isPresented: $presentsExportMenu, titleVisibility: .hidden,
                            presenting: exportMenuRequest) { request in
            Button("保存图片") { exportStore?.start(request, action: .save) }
                .accessibilityIdentifier("media-viewer.export.save")
            Button("分享／存文件") { exportStore?.start(request, action: .share) }
                .accessibilityIdentifier("media-viewer.export.share")
        }
        .onAppear {
            ownershipController.mediaDidChange(to: currentID)
        }
        .onChange(of: currentID) { _, newID in
            guard !isClosing else {
                return
            }
            chromeVisible = true
            ownershipController.mediaDidChange(to: newID)
        }
        .onDisappear {
            ownershipController.invalidateActiveSession()
            exportStore?.cancel()
        }
    }
}

private extension MediaViewer {
    var chrome: some View {
        VStack {
            ZStack {
                Text(positionText)
                    .font(Typography.font(.headline))
                    .accessibilityIdentifier("media-viewer.position")
                    .accessibilityValue((viewportDiagnosticsByID[currentID ?? ""] ?? "")
                        + " " + (imageDiagnosticsByID[currentID ?? ""] ?? ""))

                HStack {
                    Button(action: closeViewer) {
                        Image(systemName: "xmark")
                            .frame(
                                minWidth: 44,
                                minHeight: 44
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(MediaViewerCopy.close)
                    .accessibilityIdentifier(MediaViewerAccessibilityID.close)

                    Spacer(minLength: Spacing.small)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.small)
            .background(Color.black.opacity(0.72))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(MediaViewerAccessibilityID.chrome)

            Spacer()
            if currentQuality != .high, exportRequest?.descriptor.originalOnly.isLoadable == true {
                Button {
                    guard let currentID else { return }
                    highDefinitionByID[currentID, default: 0] &+= 1
                } label: {
                    Text(currentQuality.title).frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .disabled(currentQuality == .loading)
                .accessibilityHint("加载当前图片的原始资源，保持当前缩放位置")
                .accessibilityIdentifier("media-viewer.quality")
                .accessibilityValue(imageDiagnosticsByID[currentID ?? ""] ?? "")
            }
            if let exportStore {
                MediaExportControls(store: exportStore)
            }
        }
        .safeAreaPadding(.top, Spacing.small)
        .safeAreaPadding(.horizontal, Spacing.small)
    }

    var exportRequest: ImageExportRequest? {
        guard let index = presentation.items.firstIndex(where: { $0.id == currentID }) else { return nil }
        let item = presentation.items[index]
        return ImageExportRequest(mediaID: item.id, position: index + 1, descriptor: item.request)
    }

    @ViewBuilder
    func mediaPage(for mediaID: String) -> some View {
        if let item = presentation.items.first(where: {
            $0.id == mediaID
        }) {
            MediaViewerPage(
                item: item,
                imageLoader: imageLoader,
                isCurrent: mediaID == currentID,
                shouldLoad: mediaID == currentID || mediaID == adjacentPreloadID,
                highDefinitionGeneration: highDefinitionByID[mediaID] ?? 0,
                onQualityChanged: { qualityByID[mediaID] = $0 },
                onImageDiagnostics: { imageDiagnosticsByID[mediaID] = $0 },
                onViewportDiagnostics: { viewportDiagnosticsByID[mediaID] = $0 },
                resetGeneration: resetGenerationByID[mediaID] ?? 0,
                reduceMotion: reduceMotion || reductionOverride,
                ownershipController: ownershipController,
                onLongPress: {
                    guard mediaID == currentID, let exportStore, !exportStore.isBusy,
                          let request = exportRequest else { return }
                    exportMenuRequest = request
                    chromeVisible = true
                    presentsExportMenu = true
                },
                onSingleTap: {
                    chromeVisible.toggle()
                },
                onCapabilityChanged: { capability, scale in
                    guard !isClosing else {
                        return
                    }
                    if capabilityByID[mediaID] != capability {
                        capabilityByID[mediaID] = capability
                    }
                    if zoomScaleByID[mediaID] != scale {
                        zoomScaleByID[mediaID] = scale
                    }
                }
            )
        } else {
            SemanticColor.mediaBackground
        }
    }

    var currentQuality: MediaViewerQualityStatus { qualityByID[currentID ?? ""] ?? .screen }

    var adjacentPreloadID: String? {
        guard let index = presentation.items.firstIndex(where: { $0.id == currentID }), presentation.items.count > 1 else { return nil }
        let adjacent = index + 1 < presentation.items.count ? index + 1 : index - 1
        return presentation.items[adjacent].id
    }

    var positionText: String {
        guard let currentID,
              let index = presentation.items.firstIndex(where: {
                  $0.id == currentID
              }) else {
            return "0 / 0"
        }
        return "\(index + 1) / \(presentation.items.count)"
    }

    var zoomText: String {
        guard let currentID else {
            return MediaViewerCopy.zoomAccessibilityValue(1)
        }
        return MediaViewerCopy.zoomAccessibilityValue(
            zoomScaleByID[currentID] ?? 1
        )
    }

    func moveAccessibility(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment:
            moveMedia(by: 1)
        case .decrement:
            moveMedia(by: -1)
        @unknown default:
            return
        }
    }

    func moveMedia(by offset: Int) {
        guard let currentID,
              let index = presentation.items.firstIndex(where: {
                  $0.id == currentID
              }) else {
            return
        }
        let target = index + offset
        guard presentation.items.indices.contains(target) else {
            return
        }
        ownershipController.invalidateActiveSession()
        resetTransform(for: currentID)
        externalSelectionGeneration &+= 1
        self.currentID = presentation.items[target].id
    }

    func handlePagerEvent(_ event: PagerContainerEvent<String>) {
        if case let .began(transition) = event {
            transitionSourceID = transition.sourceID
            return
        }
        guard event.completedResolution == true,
              let transitionSourceID else {
            self.transitionSourceID = nil
            return
        }
        resetTransform(for: transitionSourceID)
        self.transitionSourceID = nil
    }

    func resetTransform(for mediaID: String) {
        resetGenerationByID[mediaID, default: 0] &+= 1
        capabilityByID[mediaID] = .minimumZoom
        zoomScaleByID[mediaID] = 1
    }

    func closeViewer() {
        guard !isClosing else {
            return
        }
        isClosing = true
        ownershipController.invalidateActiveSession()
        capabilityByID.removeAll(keepingCapacity: false)
        zoomScaleByID.removeAll(keepingCapacity: false)
        resetGenerationByID.removeAll(keepingCapacity: false)
        transitionSourceID = nil
        close()
    }
}
