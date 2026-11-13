//
//  DemoAutoPatient.swift
//  ToDoc
//
//  Created by seokho on 11/13/26.
//

import AVFAudio
import Foundation
import Synchronization

/// 시연·측정용 "자동 환자": 마이크 대신 합성 음성을 음성 인식기에 넣는다. 말하지 않는 동안에는 무음을 넣는다.
/// 사람이 말하지 않고도 음성 인식·통화 흐름·모델을 실제 통화와 같은 경로로 돌려 시간을 잰다
final class DemoAutoPatient: AudioRecorder {
    struct NoVoice: Error {}

    /// 문장 안에서 쉬는 자리 ("대변은 날마다|잘 보고 있어요"). 쉬는 길이는 1초
    static let pauseMark: Character = "|"

    var onEvent: ((AudioRecorderEvent) -> Void)?

    private let line = Line()
    private var voice: AVSpeechSynthesisVoice?
    private var format: AVAudioFormat?
    private var rehearsed: [String: [AVReadOnlyAudioPCMBuffer]] = [:]

    /// 목소리를 고르고 그 목소리의 소리 형식을 돌려준다 (마이크 권한은 쓰지 않는다)
    func prepare() async throws -> AVAudioFormat {
        if let format { return format }
        guard let voice = DemoSpeechCheck.bestKoreanVoice(),
              let format = await DemoSpeechCheck.synthesize("네", voice: voice).first?.format else { throw NoVoice() }
        // AI 음성이 스피커로 나오도록 재생 세션을 연다
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        self.voice = voice
        self.format = format
        return format
    }

    func start(onBuffer: @escaping @Sendable (AVReadOnlyAudioPCMBuffer) -> Void) throws {
        guard let format, let quiet = Self.silence(format) else { throw NoVoice() }
        line.start(silence: quiet, onBuffer: onBuffer)
    }

    func stop() {
        line.stop()
    }

    /// 통화 중에 바로 말할 수 있게 문장들의 소리를 미리 만들어 둔다
    func rehearse(_ sentences: [String]) async {
        guard let voice, let format, let quiet = Self.silence(format) else { return }
        for sentence in sentences where rehearsed[sentence] == nil {
            var buffers: [AVReadOnlyAudioPCMBuffer] = []
            for (index, part) in sentence.split(separator: Self.pauseMark).enumerated() {
                if index > 0 { buffers += Array(repeating: quiet, count: 10) }
                buffers += await DemoSpeechCheck.synthesize(String(part), voice: voice).map { AVReadOnlyAudioPCMBuffer(copying: $0) }
            }
            rehearsed[sentence] = buffers
        }
    }

    /// 환자가 말하듯 이 문장의 소리를 넣는다 (rehearse로 만들어 둔 문장)
    func say(_ sentence: String) {
        line.enqueue(rehearsed[sentence] ?? [])
    }

    /// 0.1초짜리 무음
    private static func silence(_ format: AVAudioFormat) -> AVReadOnlyAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate / 10)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        for channel in 0..<Int(format.channelCount) {
            if let samples = buffer.floatChannelData { memset(samples[channel], 0, Int(frames) * MemoryLayout<Float>.size) }
            if let samples = buffer.int16ChannelData { memset(samples[channel], 0, Int(frames) * MemoryLayout<Int16>.size) }
            if let samples = buffer.int32ChannelData { memset(samples[channel], 0, Int(frames) * MemoryLayout<Int32>.size) }
        }
        return AVReadOnlyAudioPCMBuffer(copying: buffer)
    }
}

/// 소리를 실제 속도로 내보낸다: 말할 소리가 있으면 그것을, 없으면 무음을. 메인 스레드 밖에서 돈다
private nonisolated final class Line: Sendable {
    private struct State {
        var queue: [AVReadOnlyAudioPCMBuffer] = []
        var pump: Task<Void, Never>?
    }

    private let state = Mutex(State())

    func start(silence: AVReadOnlyAudioPCMBuffer, onBuffer: @escaping @Sendable (AVReadOnlyAudioPCMBuffer) -> Void) {
        let pump = Task.detached { [self] in
            var due = ContinuousClock.now
            while !Task.isCancelled {
                let buffer = state.withLock { $0.queue.isEmpty ? nil : $0.queue.removeFirst() } ?? silence
                onBuffer(buffer)
                due += .milliseconds(buffer.frameLength * 1000 / max(1, Int(buffer.format.sampleRate)))
                try? await Task.sleep(until: due, clock: .continuous)
            }
        }
        state.withLock {
            $0.pump?.cancel()
            $0.pump = pump
        }
    }

    func stop() {
        state.withLock {
            $0.pump?.cancel()
            $0.pump = nil
            $0.queue = []
        }
    }

    func enqueue(_ buffers: [AVReadOnlyAudioPCMBuffer]) {
        state.withLock { $0.queue += buffers }
    }
}
