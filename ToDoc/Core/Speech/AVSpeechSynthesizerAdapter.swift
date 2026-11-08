//
//  AVSpeechSynthesizerAdapter.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//


import AVFAudio

/// 기기 기본 음성 합성. 설치된 한국어 음성 중 가장 품질 높은 음성으로 읽는다.
/// 향상됨·프리미엄 음성은 설정 > 손쉬운 사용 > 읽기 및 말하기 > 음성에서 내려받는다.
/// 오디오 세션은 AudioRecorder.prepare()가 연다. 그 전에 말하면 무음 모드에서 들리지 않을 수 있다.
final class AVSpeechSynthesizerAdapter: NSObject, SpeechSynthesizer, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language == "ko-KR" }
        // 품질이 같으면 이름순으로 정해 기기마다 같은 음성을 고른다
        .max { ($0.quality.rawValue, $0.name) < ($1.quality.rawValue, $1.name) }
        ?? AVSpeechSynthesisVoice(language: "ko-KR")
    private var started: CheckedContinuation<Void, Never>?
    private var finished: CheckedContinuation<Void, Never>?
    /// 지금 말하는 문장 (말하는 중이 아니면 nil). 멈춘 뒤 늦게 온 앞 문장의 알림이 다음 문장을 끝내지 않게 구분한다
    /// (객체를 붙잡아 둬야 같은 메모리 주소가 다른 문장에 다시 쓰이지 않는다)
    private var current: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) async {
        // 빈 문장은 시작·끝 알림이 오지 않을 수 있어 기다리지 않는다
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        current = utterance
        await withCheckedContinuation { continuation in
            started = continuation
            synthesizer.speak(utterance)
        }
    }

    func waitUntilDone() async {
        guard current != nil else { return }
        await withCheckedContinuation { finished = $0 }
    }

    /// 바로 멈추고 기다리던 speak·waitUntilDone을 끝낸다 (뒤늦게 오는 didCancel은 무시된다)
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        finish()
    }

    // 델리게이트는 메인 스레드가 아닌 곳에서 불릴 수 있어 메인으로 넘긴다
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard isCurrent(id) else { return }
            started?.resume()
            started = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in done(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in done(id) }
    }

    private func done(_ id: ObjectIdentifier) {
        guard isCurrent(id) else { return }
        finish()
    }

    /// 말이 끝났다 (시작 전에 끝난 경우도 포함해 기다리는 쪽을 모두 깨운다)
    private func finish() {
        current = nil
        started?.resume()
        started = nil
        finished?.resume()
        finished = nil
    }

    private func isCurrent(_ id: ObjectIdentifier) -> Bool {
        current.map(ObjectIdentifier.init) == id
    }
}
