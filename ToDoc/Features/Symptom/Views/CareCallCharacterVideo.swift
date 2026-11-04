import AVFoundation
import SwiftUI
import UIKit

/// Resources/Videos의 투명 배경 학로 영상을 소리 없이 반복 재생합니다.
/// 재생을 시작할 때마다 처음부터 돌고, 멈춰 있거나 동작 줄이기·백그라운드에서는 그 장면에 멈춰 보입니다.
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
            // 다시 보일 때는 처음부터 (멈췄던 동작 중간부터 이어지지 않게)
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
            // 소리 없는 영상이라 통화 오디오에 끼어들지 않게 음소거하고 외부 재생도 막는다
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
            // 영상 하나를 끝나면 처음으로 되감아 돌린다. AVPlayerLooper는 다음 바퀴 영상을 따로 불러 두는데,
            // 앱을 켜고 처음 통화를 준비할 때(모델·음성 인식을 한꺼번에 불러옴) 실기기에서 마지막 장면에 멈춘 적이 있다
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
