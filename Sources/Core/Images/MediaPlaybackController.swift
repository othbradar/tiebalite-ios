import AVFoundation
import Foundation
import Observation
import UIKit

/// One foreground playback owner across videos and voices. Never instantiated per cell.
@MainActor @Observable
final class MediaPlaybackController {
    static let shared = MediaPlaybackController()
    @ObservationIgnored private(set) var state = MediaPlaybackState() {
        didSet { presentation.update(state) }
    }
    let presentation = MediaPlaybackPresentation()
    var status: MediaPlaybackPresentation.Status { presentation.status }
    var progress: MediaPlaybackPresentation.Progress { presentation.progress }
    private(set) var player: AVPlayer?
    @ObservationIgnored private var itemObservation: NSKeyValueObservation?
    @ObservationIgnored private var playbackObservation: NSKeyValueObservation?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var failureObserver: NSObjectProtocol?
    @ObservationIgnored private var lifecycleObservers: [NSObjectProtocol] = []
    private var wantsPlayback = false
    private(set) var videoPlaybackMode = VideoPlaybackMode.manual
    @ObservationIgnored private var autoplay = VideoAutoplayState()
    @ObservationIgnored private var automaticOwner: String?

    private init() {
        let center = NotificationCenter.default
        for name in [UIApplication.didEnterBackgroundNotification, AVAudioSession.mediaServicesWereResetNotification] {
            lifecycleObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.autoplay.suspendVisible()
                    self?.stopCurrent()
                }
            })
        }
        lifecycleObservers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.startVisibleVideoIfNeeded() }
        })
        lifecycleObservers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                == AVAudioSession.InterruptionType.began.rawValue
            if began { Task { @MainActor in self?.pause() } }
        })
        lifecycleObservers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            let disconnected = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
            if disconnected { Task { @MainActor in self?.pause() } }
        })
    }

    func play(owner: String, source: MediaPlaybackSource) {
        stopCurrent()
        let ticket = state.begin(owner: owner)
        do {
            try activateAudio()
        } catch {
            state.update(ticket: ticket, phase: .failed, elapsed: 0, duration: 0)
            return
        }
        let item = AVPlayerItem(url: source.url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        wantsPlayback = true
        itemObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] _, _ in
            Task { @MainActor in self?.refresh(ticket: ticket) }
        }
        playbackObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.refresh(ticket: ticket) }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                                                      queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh(ticket: ticket) }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.finish(ticket: ticket, failed: false) }
        }
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.finish(ticket: ticket, failed: true) }
        }
        player.play()
    }

    func setVideoPlaybackMode(_ mode: VideoPlaybackMode) {
        videoPlaybackMode = mode
        autoplay.mode = mode
        if mode == .manual, automaticOwner == state.owner { stopCurrent() }
        startVisibleVideoIfNeeded()
    }

    func updateVideoVisibility(owner: String, source: MediaPlaybackSource?, visible: Bool) {
        autoplay.update(owner: owner, source: source, visible: visible)
        if !visible { stop(owner: owner) }
        startVisibleVideoIfNeeded()
    }

    private func startVisibleVideoIfNeeded() {
        guard UIApplication.shared.applicationState == .active,
              let next = autoplay.next(currentOwner: state.owner) else { return }
        play(owner: next.owner, source: next.source)
        automaticOwner = next.owner
    }

    func toggle(owner: String, source: MediaPlaybackSource) {
        guard state.owner == owner, state.phase != .failed, state.phase != .ended, let player else {
            play(owner: owner, source: source)
            return
        }
        if wantsPlayback { pause() } else {
            do {
                try activateAudio()
                wantsPlayback = true
                player.play()
                refresh(ticket: state.generation)
            } catch { finish(ticket: state.generation, failed: true) }
        }
    }

    func pause() {
        guard let player, state.owner != nil, state.phase != .ended, state.phase != .failed else { return }
        wantsPlayback = false
        player.pause()
        refresh(ticket: state.generation)
        deactivateAudio()
    }

    func stop(owner: String) {
        if state.owner == owner { stopCurrent() }
    }

    private func stopCurrent() {
        automaticOwner = nil
        wantsPlayback = false
        player?.pause()
        itemObservation = nil
        playbackObservation = nil
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        for token in [endObserver, failureObserver].compactMap({ $0 }) { NotificationCenter.default.removeObserver(token) }
        endObserver = nil
        failureObserver = nil
        player?.replaceCurrentItem(with: nil)
        player = nil
        if let owner = state.owner { state.stop(owner: owner) }
        deactivateAudio()
    }

    private func refresh(ticket: UInt64) {
        guard ticket == state.generation, let player, let item = player.currentItem,
              state.phase != .failed else { return }
        if item.status == .failed { finish(ticket: ticket, failed: true); return }
        let phase: MediaPlaybackState.Phase
        switch player.timeControlStatus {
        case .playing, .waitingToPlayAtSpecifiedRate:
            // The embedded system controls can resume or replay without going through toggle().
            if !wantsPlayback {
                do { try activateAudio(); wantsPlayback = true } catch { finish(ticket: ticket, failed: true); return }
            }
            phase = player.timeControlStatus == .playing ? .playing : .loading
        case .paused:
            guard state.phase != .ended else { return }
            if state.phase == .playing { wantsPlayback = false; deactivateAudio() }
            phase = wantsPlayback && item.status != .readyToPlay ? .loading : .paused
        @unknown default:
            phase = .paused
        }
        state.update(ticket: ticket, phase: phase, elapsed: player.currentTime().seconds, duration: item.duration.seconds)
    }

    private func finish(ticket: UInt64, failed: Bool) {
        guard ticket == state.generation else { return }
        wantsPlayback = false
        player?.pause()
        state.update(ticket: ticket, phase: failed ? .failed : .ended,
                     elapsed: player?.currentTime().seconds ?? 0, duration: player?.currentItem?.duration.seconds ?? 0)
        deactivateAudio()
    }

    private func activateAudio() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func deactivateAudio() {
        // Playback has already stopped. An audio-session release failure must not restart it.
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) } catch { return }
    }
}
