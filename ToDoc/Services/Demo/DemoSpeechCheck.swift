//
//  DemoSpeechCheck.swift
//  ToDoc
//
//  Created by seokho on 11/13/26.
//

import AVFAudio
import Foundation
import os
import Speech
import Synchronization

/// 시연·측정용: 합성 음성을 마이크 대신 음성 인식기에 실제 말하는 속도로 넣어, 받아쓰기와 문장 확정 시간을 로그로 남긴다
/// (Console에서 SpeechCheck). 사람이 말하지 않고 통화를 돌리는 방식이 쓸 만한지 보려는 시험이다
nonisolated enum DemoSpeechCheck {
    private static let log = Logger(subsystem: "ToDoc", category: "SpeechCheck")
    /// 음성 대화 시간 측정에 쓰는 대본의 답
    private static let sentences = [
        "괜찮아요", "아니요 속 편안합니다", "대변은 날마다 잘 보고 있어요", "변은 단단하게 잘 나와요", "입속은 하나도 안 헐었어요",
        "아니요", "아뇨 깨끗해요", "식사는 평소대로 해요", "눈이 자주 충혈돼요", "사흘 됐어요",
    ]

    private struct Heard {
        var partialAts: [ContinuousClock.Instant] = []
        var final: (text: String, at: ContinuousClock.Instant)?
    }

    /// 이 기기의 한국어 목소리 중 품질이 가장 좋은 것으로 대본을 읽혀 인식시킨다. 반환: 화면에 보여 줄 요약
    @concurrent
    static func run() async -> String {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ko-KR" }.sorted { $0.quality.rawValue > $1.quality.rawValue }
        for voice in voices {
            log.notice("[합성 인식] 목소리 \(voice.name, privacy: .public) · \(quality(voice), privacy: .public)")
        }
        guard let voice = voices.first else { return "한국어 목소리가 없어요." }
        do {
            let korean = Locale(identifier: "ko-KR")
            guard SpeechTranscriber.isAvailable, let locale = await SpeechTranscriber.supportedLocale(equivalentTo: korean) else {
                return "이 기기에서 한국어 음성 인식을 쓸 수 없어요."
            }
            let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            let first = await synthesize(sentences[0], voice: voice)
            guard let source = first.first?.format,
                  let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber], considering: source),
                  let converter = AVAudioConverter(from: source, to: format) else { return "합성 음성을 만들지 못했어요." }
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            try await analyzer.prepareToAnalyze(in: format)
            let (stream, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
            try await analyzer.start(inputSequence: stream)

            let heard = Mutex(Heard())
            let results = Task {
                for try await result in transcriber.results {
                    let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    heard.withLock { if result.isFinal { if !text.isEmpty { $0.final = (text, .now) } } else { $0.partialAts.append(.now) } }
                }
            }
            /// 실제 속도로 흘려 넣는다
            func feed(_ buffer: AVAudioPCMBuffer) async {
                input.yield(AnalyzerInput(buffer: buffer))
                try? await Task.sleep(for: .milliseconds(Int(Double(buffer.frameLength) / format.sampleRate * 1000)))
            }
            func silence() -> AVAudioPCMBuffer? {
                let frames = AVAudioFrameCount(format.sampleRate / 10)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
                buffer.frameLength = frames
                for channel in 0..<Int(format.channelCount) {
                    if let samples = buffer.floatChannelData { memset(samples[channel], 0, Int(frames) * MemoryLayout<Float>.size) }
                    if let samples = buffer.int16ChannelData { memset(samples[channel], 0, Int(frames) * MemoryLayout<Int16>.size) }
                }
                return buffer
            }

            var correct = 0
            var waits: [Int] = []
            for sentence in sentences {
                heard.withLock { $0 = Heard() }
                for buffer in await synthesize(sentence, voice: voice) {
                    let frames = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / source.sampleRate) + 64
                    guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { continue }
                    var fed = false
                    converter.convert(to: out, error: nil) { _, status in
                        if fed { status.pointee = .noDataNow; return nil }
                        fed = true
                        status.pointee = .haveData
                        return buffer
                    }
                    await feed(out)
                }
                let speechEnd = ContinuousClock.now
                // 무음을 넣으며 확정을 기다린다 (통화에서 환자가 말을 멈춘 뒤와 같다)
                while heard.withLock({ $0.final == nil }), ContinuousClock.now - speechEnd < .seconds(7) {
                    if let quiet = silence() { await feed(quiet) }
                }
                let got = heard.withLock { $0 }
                let same = got.final.map { letters($0.text) == letters(sentence) } ?? false
                if same { correct += 1 }
                let wait = got.final.map { ms($0.at - speechEnd) }
                if let wait { waits.append(wait) }
                let fromPartial = got.final.flatMap { final in got.partialAts.last.map { ms(final.at - $0) } }
                let gaps = zip(got.partialAts, got.partialAts.dropFirst()).map { ms($1 - $0) }.filter { $0 > 100 }
                log.notice("""
                    [합성 인식] \(same ? "O" : "X", privacy: .public) ‘\(sentence, privacy: .public)’ → ‘\(got.final?.text ?? "(확정 없음)", privacy: .public)’ · \
                    말 끝→확정 \(wait.map { "\($0)ms" } ?? "-", privacy: .public) · 마지막 중간 결과→확정 \(fromPartial.map { "\($0)ms" } ?? "-", privacy: .public) · \
                    중간 결과 간격 \(gaps, privacy: .public)
                    """)
                // 다음 문장과 섞이지 않게 잠깐 더 쉰다
                for _ in 0..<10 { if let quiet = silence() { await feed(quiet) } }
            }
            input.finish()
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            results.cancel()
            let middle = waits.sorted().dropFirst(waits.count / 2).first.map { String(format: "%.1f초", Double($0) / 1000) } ?? "-"
            let summary = "목소리 \(voice.name)(\(quality(voice))) · \(sentences.count)문장 중 \(correct)개 맞음 · 말 끝→확정 중앙 \(middle)"
            log.notice("[합성 인식] 끝 · \(summary, privacy: .public)")
            return summary
        } catch {
            log.notice("[합성 인식] 실패 · \(String(describing: error), privacy: .public)")
            return "시험하지 못했어요: \(error.localizedDescription)"
        }
    }

    /// 합성 음성을 소리 조각으로 받는다
    private static func synthesize(_ text: String, voice: AVSpeechSynthesisVoice) async -> [AVAudioPCMBuffer] {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        let collected = Mutex<(buffers: [AVAudioPCMBuffer], done: Bool)>(([], false))
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                let finished = collected.withLock { state in
                    guard !state.done else { return false }
                    if pcm.frameLength == 0 { state.done = true; return true }
                    state.buffers.append(pcm)
                    return false
                }
                if finished { continuation.resume() }
            }
        }
        return collected.withLock { $0.buffers }
    }

    private static func quality(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: "프리미엄"
        case .enhanced: "고급"
        default: "기본"
        }
    }

    private static func letters(_ text: String) -> String { String(text.filter { $0.isLetter || $0.isNumber }) }
    private static func ms(_ duration: Duration) -> Int { Int(duration / .milliseconds(1)) }
}
