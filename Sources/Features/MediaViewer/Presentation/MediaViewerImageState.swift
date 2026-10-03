import UIKit

@MainActor
struct MediaViewerImageState {
    private(set) var phase = MediaViewerImagePhase.idle
    private(set) var image: UIImage?
    private(set) var upgradeFailed = false

    mutating func begin() {
        upgradeFailed = false
        if image == nil { phase = .loading }
    }

    mutating func apply(_ outcome: MediaViewerImageLoadOutcome) {
        if let replacement = outcome.image {
            image = replacement
            phase = .rendered
        } else if image == nil {
            phase = outcome.phase
        } else {
            upgradeFailed = true
        }
    }
}

enum MediaViewerQualityStatus {
    case screen, loading, high, failed

    var title: String {
        switch self {
        case .screen: "加载原图"
        case .loading: "原图加载中…"
        case .high: "已加载原图"
        case .failed: "原图未加载，重试"
        }
    }
}
