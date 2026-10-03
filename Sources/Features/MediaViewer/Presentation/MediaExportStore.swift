import Foundation
import Observation

@Observable @MainActor
final class MediaExportStore {
    enum Action { case save, share }
    enum State: Equatable { case idle, authorizing, downloading, writing, readyToShare, sharing, saved, failed }

    private(set) var state = State.idle
    private(set) var capturedRequest: ImageExportRequest?
    private(set) var failure: ImageExportFailure?
    private(set) var isAvailableVersion = false
    private(set) var shareFile: ImageExportFile?
    private let fetcher: any ImageFileFetching
    private let writer: any PhotoLibraryWriting
    private var lastAction = Action.save
    private var operation: Task<Void, Never>?
    private var closed = false

    init(fetcher: any ImageFileFetching, writer: any PhotoLibraryWriting) {
        self.fetcher = fetcher
        self.writer = writer
    }

    var isBusy: Bool { operation != nil || shareFile != nil }

    var statusText: String {
        guard let capturedRequest else { return "" }
        let prefix = "第 \(capturedRequest.position) 张："
        switch state {
        case .idle: return ""
        case .authorizing: return prefix + "正在请求添加照片权限"
        case .downloading: return prefix + "正在下载图片"
        case .writing: return prefix + (isAvailableVersion ? "正在保存可用版本（非原图）" : "正在写入相册")
        case .readyToShare, .sharing: return prefix + (isAvailableVersion ? "分享可用版本（非原图）" : "分享图片文件")
        case .saved: return prefix + (isAvailableVersion ? "已保存可用版本（非原图）" : "已保存到相册")
        case .failed: return prefix + (failure?.message ?? "操作失败，请重试")
        }
    }

    func start(_ request: ImageExportRequest, action: Action) {
        guard !isBusy, !closed else { return }
        capturedRequest = request
        lastAction = action
        failure = nil
        isAvailableVersion = false
        state = action == .save ? .authorizing : .downloading
        operation = Task { await perform(request, action: action) }
    }

    func retry() {
        guard let capturedRequest else { return }
        start(capturedRequest, action: lastAction)
    }

    func shareCapturedImage() {
        guard let capturedRequest else { return }
        start(capturedRequest, action: .share)
    }

    func cancel() {
        closed = true
        operation?.cancel()
        // A presented activity owns shareFile until its completion/dismissal callback.
        if state == .readyToShare { shareFinished(completed: false) }
    }

    func shareDidPresent() {
        guard shareFile != nil else { return }
        state = .sharing
    }

    func shareFinished(completed: Bool) {
        _ = completed // Both completion and cancellation release this owned file.
        guard let file = shareFile else { return }
        shareFile = nil
        operation = Task {
            await fetcher.remove(file)
            state = .idle
            operation = nil
        }
    }

    func waitForOperation() async { await operation?.value }

    private func perform(_ request: ImageExportRequest, action: Action) async {
        var ownedFile: ImageExportFile?
        do {
            if action == .save { try await writer.authorizeAddOnly() }
            try Task.checkCancellation()
            state = .downloading
            let file = try await fetcher.fetch(request)
            ownedFile = file
            try Task.checkCancellation()
            isAvailableVersion = !file.isOriginal
            if action == .save {
                state = .writing
                try await writer.write(file)
                await fetcher.remove(file)
                ownedFile = nil
                try Task.checkCancellation()
                state = .saved
            } else {
                shareFile = file
                ownedFile = nil
                state = .readyToShare
            }
        } catch {
            if let ownedFile { await fetcher.remove(ownedFile) }
            if error is CancellationError || Task.isCancelled {
                state = .idle
            } else {
                failure = error as? ImageExportFailure ?? .download
                state = .failed
            }
        }
        operation = nil
    }
}
