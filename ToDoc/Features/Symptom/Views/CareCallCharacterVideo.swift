import AVFoundation
import SwiftUI
import UIKit

/// Resources/Videos의 투명 배경 학로 영상을 소리 없이 반복 재생합니다.
/// 멈춰 있거나 동작 줄이기·백그라운드에서는 첫 장면에 멈춰 보입니다.
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
        if isPlaying { view.player.play() } else { view.player.pause() }
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.player.pause()
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?

        init(name: String) {
            super.init(frame: .zero)
            backgroundColor = .clear
            isUserInteractionEnabled = false
            // 소리 없는 영상이라 통화 오디오에 끼어들지 않게 음소거하고 외부 재생도 막는다
            player.isMuted = true
            player.allowsExternalPlayback = false
            player.preventsDisplaySleepDuringVideoPlayback = false
            let layer = layer as! AVPlayerLayer
            layer.player = player
            layer.videoGravity = .resizeAspect
            if let url = Bundle.main.url(forResource: name, withExtension: "mov") {
                looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            } else {
                #if DEBUG
                assertionFailure("\(name).mov 리소스가 없습니다.")
                #endif
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}
