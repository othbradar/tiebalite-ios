import SwiftUI

@MainActor
@Observable
final class TiebaImagePresentation {
    enum Phase: String {
        case loading = "正在加载"
        case rendered = "已加载"
        case failed = "加载失败"
        case cancelled = "加载已取消"
    }

    private(set) var request: ImageRequest?
    private(set) var phase = Phase.loading
    private(set) var image: UIImage?
    private var generation: UInt64 = 0

    func load(_ request: ImageRequest, using loader: any ImageLoading) async {
        generation &+= 1
        let currentGeneration = generation
        self.request = request
        image = nil
        phase = .loading
        do {
            let payload = try await loader.load(request)
            try Task.checkCancellation()
            guard currentGeneration == generation else { return }
            image = payload.displayImage()
            phase = image == nil ? .failed : .rendered
        } catch is CancellationError {
            guard currentGeneration == generation else { return }
            phase = .cancelled
        } catch {
            guard currentGeneration == generation else { return }
            phase = Task.isCancelled ? .cancelled : .failed
        }
    }

    func displayedImage(for currentRequest: ImageRequest?) -> UIImage? {
        request == currentRequest && phase == .rendered ? image : nil
    }

    func displayedPhase(for currentRequest: ImageRequest?) -> Phase {
        guard currentRequest != nil else { return .failed }
        return request == currentRequest ? phase : .loading
    }
}

/// Presentation only. The injected loader owns fetching, decoding and caching.
struct TiebaRemoteImageView: View {
    let resource: ImageResourceDescriptor?
    let imageLoader: any ImageLoading
    let purpose: ImageRequestPurpose
    let accessibilityLabel: String

    @Environment(\.displayScale) private var displayScale
    @State private var presentation = TiebaImagePresentation()
    @State private var size = CGSize.zero

    var body: some View {
        ZStack {
            TiebaParityTokens.neutralFill
            if let image = presentation.displayedImage(for: request) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
            } else if phase == .failed {
                Rectangle()
                    .fill(SemanticColor.secondaryText.opacity(0.35))
                    .frame(width: 8, height: 1)
            }
        }
        .clipped()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .task(id: request) {
            guard let request else { return }
            await presentation.load(request, using: imageLoader)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(phase.rawValue)
    }

    private var phase: TiebaImagePresentation.Phase {
        if resource != nil, request == nil { return .loading }
        return presentation.displayedPhase(for: request)
    }

    private var request: ImageRequest? {
        guard let resource, size.width > 0, size.height > 0 else { return nil }
        return ImageRequest(
            resource: resource,
            targetPixelSize: .normalized(
                pointWidth: size.width,
                pointHeight: size.height,
                displayScale: displayScale,
                purpose: purpose
            ),
            purpose: purpose,
            resizeMode: .fill
        )
    }
}
