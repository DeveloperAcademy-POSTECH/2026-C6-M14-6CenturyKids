import AVFoundation
import SwiftUI
import UIKit

/// 홈이 보일 때만 재생하는 무음 장식 영상입니다.
struct HomeHakroVideo: View {
    let isVisible: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HomeHakroPlayer(shouldPlay: isVisible && scenePhase == .active && !reduceMotion)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct HomeHakroPlayer: UIViewRepresentable {
    let shouldPlay: Bool

    func makeUIView(context: Context) -> HomeHakroPlayerView {
        HomeHakroPlayerView(frame: .zero)
    }

    func updateUIView(_ uiView: HomeHakroPlayerView, context: Context) {
        uiView.updatePlayback(shouldPlay: shouldPlay)
    }

    static func dismantleUIView(_ uiView: HomeHakroPlayerView, coordinator: ()) {
        uiView.stop()
    }
}

private final class HomeHakroPlayerView: UIView {
    private let playerLayer = AVPlayerLayer()
    private let poster = UIImageView(image: UIImage(named: "HomeHakroPoster") ?? UIImage(named: "HakroDoctor"))
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var readinessObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var shouldPlay = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        playerLayer.isOpaque = false
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
        poster.contentMode = .scaleAspectFit
        poster.backgroundColor = .clear
        addSubview(poster)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
        poster.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshPlayback()
    }

    func updatePlayback(shouldPlay: Bool) {
        self.shouldPlay = shouldPlay
        refreshPlayback()
    }

    private func refreshPlayback() {
        guard shouldPlay, window != nil else {
            player?.pause()
            refreshPoster()
            return
        }
        preparePlayerIfNeeded()
        player?.play()
        refreshPoster()
    }

    private func preparePlayerIfNeeded() {
        guard player == nil,
              let url = Bundle.main.url(forResource: "HomeHakroGreeting", withExtension: "mov") else { return }
        let player = AVQueuePlayer()
        player.isMuted = true
        player.volume = 0
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        self.player = player
        playerLayer.player = player
        readinessObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.refreshPoster() }
        }
        statusObservation = player.observe(\.currentItem?.status, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.refreshPoster() }
        }
    }

    private func refreshPoster() {
        let showsVideo = shouldPlay && window != nil && playerLayer.isReadyForDisplay
            && player?.currentItem?.status == .readyToPlay
        playerLayer.isHidden = !showsVideo
        poster.isHidden = showsVideo
    }

    func stop() {
        shouldPlay = false
        player?.pause()
        readinessObservation?.invalidate()
        readinessObservation = nil
        statusObservation?.invalidate()
        statusObservation = nil
        playerLayer.player = nil
        looper?.disableLooping()
        looper = nil
        player?.removeAllItems()
        player = nil
        refreshPoster()
    }
}
