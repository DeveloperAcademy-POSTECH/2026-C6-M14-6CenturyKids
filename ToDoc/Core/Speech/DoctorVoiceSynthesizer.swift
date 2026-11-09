//
//  DoctorVoiceSynthesizer.swift
//  ToDoc
//
//  Created by seokho on 11/9/26.
//

import AVFoundation

/// 의사 선생님 녹음으로 읽는다: 문장을 조각으로 나눠 녹음 파일(DoctorVoice/*.m4a)을 이어 튼다.
/// 녹음이 없는 조각이 있는 문장은 기기 음성(fallback)으로 읽는다.
/// 오디오 세션은 AudioRecorder.prepare()가 연다 (기기 음성과 같다)
final class DoctorVoiceSynthesizer: SpeechSynthesizer {
    private let clips: DoctorVoiceClips
    private let fallback: SpeechSynthesizer
    private let bundle: Bundle
    private let player = AVQueuePlayer()
    /// 지금 트는 문장의 마지막 조각 (트는 중이 아니면 nil). 이 조각이 끝나면 문장이 끝난 것
    private var lastItem: AVPlayerItem?
    private var endObservers: [NSObjectProtocol] = []
    private var finished: CheckedContinuation<Void, Never>?

    init(clips: DoctorVoiceClips, fallback: SpeechSynthesizer, bundle: Bundle = .main) {
        self.clips = clips
        self.fallback = fallback
        self.bundle = bundle
    }

    /// 녹음을 틀기 시작하면 바로 돌아온다 (파일이라 기기 음성처럼 소리가 늦게 나지 않는다)
    func speak(_ text: String) async {
        let names = clips.clipNames(for: text) ?? []
        let urls = names.compactMap { bundle.url(forResource: $0, withExtension: "m4a") }
        guard !urls.isEmpty, urls.count == names.count else {
            await fallback.speak(text)
            return
        }
        let items = urls.map(AVPlayerItem.init(url:))
        items.forEach { player.insert($0, after: nil) }
        let last = items[items.count - 1]
        lastItem = last
        // 끝까지 틀었거나 중간에 실패해도 문장을 끝낸다 (기다리는 쪽이 멈추지 않게)
        endObservers = [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification].map {
            NotificationCenter.default.addObserver(forName: $0, object: last, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.finish() }
            }
        }
        player.play()
    }

    func waitUntilDone() async {
        guard lastItem != nil else {
            await fallback.waitUntilDone()
            return
        }
        await withCheckedContinuation { finished = $0 }
    }

    /// 바로 멈추고 기다리던 waitUntilDone을 끝낸다
    func stop() {
        fallback.stop()
        finish()
    }

    private func finish() {
        endObservers.forEach(NotificationCenter.default.removeObserver)
        endObservers = []
        player.removeAllItems()
        lastItem = nil
        finished?.resume()
        finished = nil
    }
}
