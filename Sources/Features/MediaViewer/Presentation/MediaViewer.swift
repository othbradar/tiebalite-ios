import SwiftUI
import UIKit

@MainActor
struct MediaViewer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.motionReductionOverride) private var reductionOverride

    let presentation: MediaViewerPresentation
    let imageLoader: any ImageLoading
    let close: () -> Void

    @State private var currentID: String?
    @State private var externalSelectionGeneration: UInt64 = 0
    @State private var chromeVisible = true
    @State private var capabilityByID: [String: MediaPageCapability] = [:]
    @State private var zoomScaleByID: [String: Double] = [:]
    @State private var resetGenerationByID: [String: UInt64] = [:]
    @State private var transitionSourceID: String?
    @State private var ownershipController =
        MediaGestureOwnershipController<String>()
    @State private var isClosing = false

    init(
        presentation: MediaViewerPresentation,
        imageLoader: any ImageLoading,
        close: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.imageLoader = imageLoader
        self.close = close
        _currentID = State(initialValue: presentation.initialMediaID)
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
        }
    }
}

private extension MediaViewer {
    var chrome: some View {
        VStack {
            HStack(spacing: Spacing.small) {
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

                Text(positionText)
                    .font(Typography.font(.headline))
                    .accessibilityHidden(true)

                Spacer(minLength: Spacing.small)

                Button {
                    moveMedia(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canMoveMedia(by: -1))
                .accessibilityLabel(MediaViewerCopy.previous)
                .accessibilityIdentifier(MediaViewerAccessibilityID.previous)

                Button {
                    moveMedia(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canMoveMedia(by: 1))
                .accessibilityLabel(MediaViewerCopy.next)
                .accessibilityIdentifier(MediaViewerAccessibilityID.next)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.small)
            .background(Color.black.opacity(0.72))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(MediaViewerAccessibilityID.chrome)

            Spacer()
        }
        .safeAreaPadding(.top, Spacing.small)
        .safeAreaPadding(.horizontal, Spacing.small)
    }

    @ViewBuilder
    func mediaPage(for mediaID: String) -> some View {
        if let item = presentation.items.first(where: {
            $0.id == mediaID
        }) {
            MediaViewerPage(
                item: item,
                imageLoader: imageLoader,
                resetGeneration: resetGenerationByID[mediaID] ?? 0,
                reduceMotion: reduceMotion || reductionOverride,
                ownershipController: ownershipController,
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

    func canMoveMedia(by offset: Int) -> Bool {
        guard let currentID,
              let index = presentation.items.firstIndex(where: {
                  $0.id == currentID
              }) else {
            return false
        }
        return presentation.items.indices.contains(index + offset)
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
