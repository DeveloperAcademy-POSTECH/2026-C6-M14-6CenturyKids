//
//  SupertonicAdapter.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//


import AVFAudio

/// Supertonic 음성 합성 (목소리 M3). 모델 파일은 tools/download_supertonic.sh로 받는다.
/// 모델이 앱에 없거나 불러오지 못하면, 또는 그 문장 합성에 실패하면 `fallback`(시스템 음성)으로 말한다.
/// 모델 라이선스(OpenRAIL-M)상 의료 조언으로 볼 수 있는 응급 안내는 이 어댑터가 아니라 시스템 음성으로 읽는다 (엔진에서 분기).
/// 만들자마자 모델을 메모리에 올리므로(약 0.9GB) 앱 시작이 아니라 케어콜을 시작할 때 만든다.
/// 전화 등으로 재생이 중단되면 끝 알림이 오지 않으니, 오디오 중단 알림을 받으면 stop()을 부른다.
final class SupertonicAdapter: NSObject, SpeechSynthesizer, AVAudioPlayerDelegate {
    private let fallback: SpeechSynthesizer
    /// 모델을 메인 스레드 밖에서 불러온다 (약 0.5초). 없거나 실패하면 nil
    private let voice = Task.detached(priority: .userInitiated) { try? SupertonicVoice() }
    private var player: AVAudioPlayer?
    private var finished: CheckedContinuation<Void, Never>?
    /// 지금 말을 시스템 음성이 하는 중인지
    private var speakingByFallback = false
    /// stop()마다 늘린다. 합성하는 동안 멈췄으면 합성이 끝나도 재생하지 않는다
    private var generation = 0

    init(fallback: SpeechSynthesizer) {
        self.fallback = fallback
    }

    func speak(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let current = generation
        speakingByFallback = false
        if let voice = await voice.value,
           let samples = try? await voice.utterance(text),
           let player = try? AVAudioPlayer(data: SupertonicVoice.wavData(samples, sampleRate: voice.sampleRate)) {
            guard current == generation else { return }
            self.player = player
            player.delegate = self
            player.play()
            return
        }
        guard current == generation else { return }
        speakingByFallback = true
        await fallback.speak(text)
    }

    func waitUntilDone() async {
        if speakingByFallback {
            await fallback.waitUntilDone()
            speakingByFallback = false
            return
        }
        guard player?.isPlaying == true else { return }
        await withCheckedContinuation { finished = $0 }
    }

    /// 바로 멈추고 기다리던 waitUntilDone을 끝낸다 (AVAudioPlayer.stop()은 델리게이트를 부르지 않는다)
    func stop() {
        generation += 1
        player?.stop()
        player = nil
        fallback.stop()
        speakingByFallback = false
        finished?.resume()
        finished = nil
    }

    // 델리게이트는 메인 스레드가 아닌 곳에서 불릴 수 있어 메인으로 넘긴다
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in done(id) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in done(id) }
    }

    /// 지금 재생 중인 소리가 끝났을 때만 기다리는 쪽을 깨운다 (멈춘 뒤 늦게 온 알림은 무시)
    private func done(_ id: ObjectIdentifier) {
        guard let player, ObjectIdentifier(player) == id else { return }
        self.player = nil
        finished?.resume()
        finished = nil
    }
}
