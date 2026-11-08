import AVFoundation
import SwiftUI
import UIKit

/// 앱을 새로 실행할 때 한 번 재생하고 기존 시작 화면으로 이어집니다.
struct SplashVideoView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color(white: 253.0 / 255.0)
            SplashVideoPlayer(shouldPlay: scenePhase == .active && !reduceMotion, onFinished: onFinished)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("속닥을 시작하고 있어요")
        .task(id: reduceMotion) {
            if reduceMotion {
                onFinished()
                return
            }
            // 파일이나 디코더에 문제가 생겨도 시작 화면을 계속 가리지 않습니다.
            do {
                try await Task.sleep(for: .seconds(6))
                onFinished()
            } catch { }
        }
    }
}

private struct SplashVideoPlayer: UIViewRepresentable {
    let shouldPlay: Bool
    let onFinished: () -> Void

    func makeUIView(context: Context) -> SplashPlayerView {
        SplashPlayerView()
    }

    func updateUIView(_ uiView: SplashPlayerView, context: Context) {
        uiView.update(shouldPlay: shouldPlay, onFinished: onFinished)
    }

    static func dismantleUIView(_ uiView: SplashPlayerView, coordinator: ()) {
        uiView.stop()
    }
}

private final class SplashPlayerView: UIView {
    private let playerLayer = AVPlayerLayer()
    private let poster = UIImageView(image: UIImage(named: "SplashPoster"))
    private var player: AVPlayer?
    private var itemObservation: NSKeyValueObservation?
    private var displayObservation: NSKeyValueObservation?
    private var notifications: [NSObjectProtocol] = []
    private var onFinished: (() -> Void)?
    private var shouldPlay = false
    private var didFinish = false

    init() {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 253.0 / 255.0, alpha: 1)
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
        poster.contentMode = .scaleAspectFit
        poster.backgroundColor = backgroundColor
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

    func update(shouldPlay: Bool, onFinished: @escaping () -> Void) {
        self.shouldPlay = shouldPlay
        self.onFinished = onFinished
        if player == nil && !didFinish { preparePlayer() }
        refreshPlayback()
    }

    private func preparePlayer() {
        guard let url = Bundle.main.url(forResource: "SplashIntro", withExtension: "mp4") else {
            Task { @MainActor [weak self] in self?.finish() }
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.volume = 0
        player.preventsDisplaySleepDuringVideoPlayback = false
        self.player = player
        playerLayer.player = player
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let failed = item.status == .failed
            Task { @MainActor [weak self] in
                if failed { self?.finish() }
            }
        }
        displayObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.poster.isHidden = self.playerLayer.isReadyForDisplay
            }
        }
        for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
            notifications.append(NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.finish() }
            })
        }
    }

    private func refreshPlayback() {
        if shouldPlay && window != nil && !didFinish {
            player?.play()
        } else {
            player?.pause()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        let completion = onFinished
        stop()
        completion?()
    }

    func stop() {
        player?.pause()
        itemObservation?.invalidate()
        itemObservation = nil
        displayObservation?.invalidate()
        displayObservation = nil
        notifications.forEach(NotificationCenter.default.removeObserver)
        notifications.removeAll()
        playerLayer.player = nil
        player?.replaceCurrentItem(with: nil)
        player = nil
        onFinished = nil
    }
}
