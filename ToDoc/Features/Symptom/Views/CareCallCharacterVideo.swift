import AVFoundation
import SwiftUI
import UIKit

struct CareCallCharacterVideo: View {
    let name: String
    var isPlaying = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        LoopingVideo(name: name, isPlaying: isPlaying && !reduceMotion && scenePhase == .active)
            .accessibilityHidden(true)
    }
}

private struct LoopingVideo: UIViewRepresentable {
    let name: String
    let isPlaying: Bool

    func makeUIView(context: Context) -> PlayerView { PlayerView(name: name) }

    func updateUIView(_ view: PlayerView, context: Context) {
        guard isPlaying != view.isPlaying else { return }
        view.isPlaying = isPlaying
        if isPlaying {
            view.player.seek(to: .zero)
            view.player.play()
        } else {
            view.player.pause()
        }
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.player.pause()
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        let player = AVPlayer()
        var isPlaying = false
        private var endObserver: NSObjectProtocol?
        private var statusObservation: NSKeyValueObservation?

        init(name: String) {
            super.init(frame: .zero)
            backgroundColor = .clear
            isUserInteractionEnabled = false
            player.isMuted = true
            player.allowsExternalPlayback = false
            player.preventsDisplaySleepDuringVideoPlayback = false
            let layer = layer as! AVPlayerLayer
            layer.player = player
            layer.videoGravity = .resizeAspect
            guard let url = Bundle.main.url(forResource: name, withExtension: "mov") else {
                #if DEBUG
                assertionFailure("\(name).mov 리소스가 없습니다.")
                #endif
                return
            }
            let item = AVPlayerItem(url: url)
            player.actionAtItemEnd = .none
            player.replaceCurrentItem(with: item)
            endObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.player.seek(to: .zero) }
            }
            // 재생 중이어야 하는데 시스템이 멈추면(오디오 세션 변경 등) 다시 튼다
            statusObservation = player.observe(\.timeControlStatus) { [weak self] player, _ in
                DispatchQueue.main.async {
                    guard let self, self.isPlaying, player.timeControlStatus == .paused else { return }
                    player.play()
                }
            }
        }

        deinit {
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}
