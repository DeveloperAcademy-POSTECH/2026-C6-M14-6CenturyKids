//
//  SpeechAnalyzerAdapter.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import AVFAudio
import os
import Speech
import Synchronization

/// SpeechAnalyzer 한국어 음성 인식. 마이크(AudioRecorder) 소리를 기기 안에서 글자로 바꾼다.
/// 통화 동안 분석기 하나를 계속 돌리고, 듣는 중이 아닐 때(AI가 말하는 동안·정지 후) 들어온 소리는 버린다.
final class SpeechAnalyzerAdapter: SpeechRecognizer {
    /// 확정 결과 뒤 이만큼 새 결과가 없으면 말이 끝난 것으로 본다
    private static let silence: Duration = .seconds(1)
    /// 관리자 설정 토글이 저장하는 키. 값이 없으면 켜짐. 켜면 문장이 늦게 확정된 턴은 무음을 더 기다리지 않고 끝낸다
    static let skipSilenceKey = "demo.speechSkipSilence"
    static var skipSilenceEnabled: Bool { UserDefaults.standard.object(forKey: skipSilenceKey) as? Bool ?? true }
    /// 확정이 마지막 중간 결과보다 이만큼 넘게 늦었으면 인식기가 이미 말이 끝나기를 기다린 것으로 본다
    /// (실기기에서 말이 끝난 뒤의 확정은 1.9~2.9초 뒤, 말하는 도중의 확정은 바로 온다)
    private static let lateFinal: Duration = .milliseconds(1500)
    /// "다 말했어요"를 누른 뒤 문장 확정을 이만큼 기다린다. 넘으면 마지막 중간 결과를 붙여 넘어간다
    private static let closeTimeout: Duration = .milliseconds(1500)
    /// 누른 뒤 확정을 받고도 뒤따라오는 결과가 있으면 받도록 기다리는 시간
    private static let closeGrace: Duration = .milliseconds(150)
    /// 관리자 설정에 보여 줄 지난 답의 소리 크기 (수음 강도를 현장에서 맞출 때 본다)
    static let lastLevelsKey = "demo.micLastLevels"
    /// 듣기 구간 시간 로그 (Console에서 SpeechTiming). 말소리가 끝난 뒤 문장이 확정되고 턴이 끝나기까지를 잰다
    private static let timingLog = Logger(subsystem: "ToDoc", category: "SpeechTiming")

    private let recorder: AudioRecorder
    private let feed = AnalyzerFeed()
    private var analyzer: SpeechAnalyzer?
    private var resultsTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?
    /// 이번 턴에 확정된 문장
    private var finalized = ""
    /// 이번 턴에서 아직 확정되지 않은 마지막 중간 결과
    private var pending = ""
    /// "다 말했어요"를 눌러 마무리하는 중. 새 소리는 받지 않고 이미 들어간 말의 확정만 기다린다
    private var closing = false
    /// 누른 시각과 그때까지 들은 말 (확정이 빈 문장으로 와도 턴이 빈 답으로 끝나지 않게)
    private var closedAt: ContinuousClock.Instant?
    private var heardAtClose = ""
    /// 이번 턴에서 지금까지 들은 말을 받는 쪽 (중간 결과 포함)
    private var onPartial: ((String, Bool) -> Void)?
    private var turnEnd: CheckedContinuation<String, Never>?
    private var micOn = false
    /// 시간 로그용: 이번 턴의 마지막 중간 결과·마지막 확정 시각, 그 확정 때까지 마지막으로 말소리가 들린 시각, 확정 횟수
    private var lastPartialAt: ContinuousClock.Instant?
    private var finalAt: ContinuousClock.Instant?
    private var loudAtFinal: ContinuousClock.Instant?
    private var finals = 0
    /// 시간 로그용: 이번 턴의 확정마다, 그 직전 중간 결과에서 확정까지 걸린 시간(ms). 짧으면 말하는 도중의 확정이다
    private var finalGaps: [Int] = []

    init(recorder: AudioRecorder) {
        self.recorder = recorder
    }

    /// 통화 없이 화면을 나가면(닫기·미루기·채팅으로 전환) stop()이 불리지 않는다.
    /// 분석기는 이 객체가 풀려도 계속 돌며 앱의 인식기 한도(2개)를 차지해, 세 번째 준비부터 실패한다 (SFSpeechErrorDomain 16)
    isolated deinit {
        resultsTask?.cancel()
        silenceTask?.cancel()
        feed.finish()
        guard let analyzer else { return }
        Task { await analyzer.cancelAndFinishNow() }
    }

    func prepare() async throws {
        do {
            // 마이크 권한을 먼저 받는다 (거부하면 에셋을 내려받지 않는다)
            let micFormat = try await recorder.prepare()
            let module = try await makeTranscriber()
            // 한국어 인식 에셋이 없으면 처음 한 번 내려받는다
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module], considering: micFormat) else {
                throw SpeechRecognizerError.noAudioFormat
            }
            let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
            feed.configure(converter: AnalyzerInputConverter(analyzerFormat: format), continuation: continuation)
            let analyzer = SpeechAnalyzer(modules: [module])
            try await analyzer.prepareToAnalyze(in: format)
            try await analyzer.start(inputSequence: stream)
            self.analyzer = analyzer
        } catch {
            // 중간에 실패하면 이미 시작한 결과 수신·분석기를 정리한다
            await stop()
            throw error
        }
    }

    /// 마이크는 준비 때가 아니라 통화를 시작할 때 켠다 (준비 화면에서 마이크 표시가 켜지지 않게)
    func startMicrophone() throws {
        guard analyzer != nil, !micOn else { return }
        try recorder.start { [feed] buffer in feed.send(buffer) }
        micOn = true
    }

    func listen(onPartial: @escaping (_ heard: String, _ isFinal: Bool) -> Void) async throws -> String {
        // 준비 전이나 정지 후에는 들을 수 없으니 바로 빈 문장을 돌려준다 (영원히 기다리지 않게)
        guard analyzer != nil else { return "" }
        try startMicrophone()
        finalized = ""
        pending = ""
        closing = false
        closedAt = nil
        heardAtClose = ""
        lastPartialAt = nil
        finalAt = nil
        loudAtFinal = nil
        finals = 0
        finalGaps = []
        self.onPartial = onPartial
        feed.listening = true
        return await withCheckedContinuation { turnEnd = $0 }
    }

    func finishListening() {
        let heard = Self.joined(finalized, pending)
        guard turnEnd != nil, !closing, !heard.isEmpty else { return }
        closing = true
        closedAt = .now
        heardAtClose = heard
        feed.listening = false
        silenceTask?.cancel()
        // 모두 확정된 말이면 바로 넘어간다
        guard !pending.isEmpty else { return finishTurn() }
        // 이미 들어간 말이 끝난 것으로 인식기가 알도록 무음을 넣고, 그 확정을 기다린다
        feed.flush()
        endTurn(after: Self.closeTimeout)
    }

    func stop() async {
        feed.listening = false
        recorder.stop()
        micOn = false
        feed.finish()
        await analyzer?.cancelAndFinishNow()
        analyzer = nil
        resultsTask?.cancel()
        silenceTask?.cancel()
        finishTurn()
    }

    /// 한국어 SpeechTranscriber, 이 기기에 없으면 DictationTranscriber. 결과를 받기 시작한다
    private func makeTranscriber() async throws -> any SpeechModule {
        let korean = Locale(identifier: "ko-KR")
        if SpeechTranscriber.isAvailable, let locale = await SpeechTranscriber.supportedLocale(equivalentTo: korean) {
            let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            observe(transcriber.results.map { (String($0.text.characters), $0.isFinal) })
            return transcriber
        }
        if let locale = await DictationTranscriber.supportedLocale(equivalentTo: korean) {
            let dictation = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
            observe(dictation.results.map { (String($0.text.characters), $0.isFinal) })
            return dictation
        }
        throw SpeechRecognizerError.koreanUnsupported
    }

    /// 인식 결과(글자, 확정 여부)를 받는다. 두 인식기의 결과 타입이 달라 글자·확정 여부로 바꿔 받는다
    private func observe(_ results: some AsyncSequence<(String, Bool), any Error>) {
        resultsTask = Task { [weak self] in
            do {
                for try await (text, isFinal) in results { self?.receive(text, isFinal: isFinal) }
            } catch {}
            // 인식이 끝나거나 실패하면 기다리던 턴을 그때까지 들은 문장으로 끝낸다
            self?.finishTurn()
        }
    }

    private func receive(_ text: String, isFinal: Bool) {
        guard feed.listening || closing else { return }
        // 새 결과가 왔다 = 아직 말하는 중이니 무음 타이머를 다시 잰다 (마무리 중에는 기다리는 시간을 늘리지 않는다)
        if !closing { silenceTask?.cancel() }
        let sentence = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 중간 결과는 확정 문장 뒤에 붙여 보여 주기만 한다 (말하는 동안 바뀔 수 있어 턴 문장에는 넣지 않는다)
        guard isFinal else {
            lastPartialAt = .now
            pending = sentence
            onPartial?(Self.joined(finalized, sentence), false)
            return
        }
        finalAt = .now
        if let lastPartialAt { finalGaps.append(Int((ContinuousClock.now - lastPartialAt) / .milliseconds(1))) }
        loudAtFinal = feed.lastLoudAt
        finals += 1
        finalized = Self.joined(finalized, sentence)
        pending = ""
        onPartial?(finalized, true)
        if closing { return endTurn(after: Self.closeGrace) }
        // 잡음만 들렸으면(확정 문장 없음) 계속 듣는다
        guard !finalized.isEmpty else { return }
        if Self.skipSilenceEnabled, let lastPartialAt, .now - lastPartialAt > Self.lateFinal {
            finishTurn()
            return
        }
        endTurn(after: Self.silence)
    }

    /// 이만큼 뒤에 턴을 끝낸다. 그 전에 다시 부르면 새로 잰다
    private func endTurn(after wait: Duration) {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self?.finishTurn()
        }
    }

    /// 턴이 끝날 때 한 줄: 말소리 끝 → 확정, 마지막 중간 결과 → 확정, 확정 → 턴 끝(무음 대기), 확정 횟수(2번 이상이면 말이 이어진 것)와 확정마다 직전 중간 결과 뒤 몇 ms였는지
    private func logTiming() {
        guard turnEnd != nil else { return }
        let closed = closedAt.map { " · 다 말했어요 누름→턴 끝 \(Int((ContinuousClock.now - $0) / .milliseconds(1)))ms(\(pending.isEmpty ? "확정 받음" : "중간 결과로 넘어감"))" } ?? ""
        guard let finalAt else {
            if closedAt != nil { Self.timingLog.notice("[듣기] 확정 없음\(closed, privacy: .public)") }
            return
        }
        func gap(_ from: ContinuousClock.Instant?) -> String { from.map { "\(Int((finalAt - $0) / .milliseconds(1)))ms" } ?? "모름" }
        let wait = Int((ContinuousClock.now - finalAt) / .milliseconds(1))
        let level = String(format: "%.3f", feed.maxLevel)
        let blocked = String(format: "%.3f", feed.maxBlockedLevel)
        Self.timingLog.notice("""
            [듣기] 소리 끝→확정 \(gap(self.loudAtFinal), privacy: .public) · 마지막 중간 결과→확정 \(gap(self.lastPartialAt), privacy: .public) · \
            확정→턴 끝 \(wait, privacy: .public)ms · 확정 \(self.finals, privacy: .public)번\(self.finalGaps.description, privacy: .public) · 최대 소리 \(level, privacy: .public) · \
            걸러진 최대 \(blocked, privacy: .public)\(closed, privacy: .public)
            """)
    }

    private static func joined(_ head: String, _ tail: String) -> String {
        head.isEmpty || tail.isEmpty ? head + tail : head + " " + tail
    }

    private func finishTurn() {
        logTiming()
        silenceTask?.cancel()
        feed.listening = false
        onPartial = nil
        if turnEnd != nil {
            UserDefaults.standard.set(String(format: "목소리 최대 %.2f · 걸러진 소리 최대 %.2f", feed.maxLevel, feed.maxBlockedLevel),
                                      forKey: Self.lastLevelsKey)
        }
        // 확정을 받지 못하고 마무리했으면 마지막 중간 결과를 붙인다
        let heard = Self.joined(finalized, pending)
        turnEnd?.resume(returning: heard.isEmpty ? heardAtClose : heard)
        turnEnd = nil
        closing = false
    }
}

/// 마이크 소리를 분석기로 넘긴다. 마이크 콜백(오디오 스레드)과 메인 스레드가 함께 쓰므로 잠금으로 보호한다.
nonisolated private final class AnalyzerFeed: Sendable {
    private struct State {
        var listening = false
        var converter: AnalyzerInputConverter?
        var continuation: AsyncStream<AnalyzerInput>.Continuation?
        var lastLoudAt: ContinuousClock.Instant?
        var maxLevel: Float = 0
        var gate = MicGate(threshold: 0)
        /// 걸러진 소리 중 가장 컸던 것 (주변 소리가 기준에 얼마나 가까운지 본다)
        var maxBlockedLevel: Float = 0
        /// 걸러질 소리를 한 박자 잡아 둔 것과 그 크기. 바로 다음 소리에 문이 열리면 그대로 넘겨 말머리가 잘리지 않게 한다
        var held: (buffer: AVAudioPCMBuffer, level: Float)?
        /// 마이크 소리 형식 (무음을 만들 때 쓴다)
        var format: AVAudioFormat?

        /// 분석기 형식으로 바꿔 넘긴다
        func yield(_ buffer: AVAudioPCMBuffer) {
            guard let inputs = try? converter?.convert(buffer, at: nil) else { return }
            for input in inputs { continuation?.yield(input) }
        }
    }

    /// 이 크기(RMS)를 넘으면 말소리로 본다. 시간 로그용 어림값이라 턴마다 최대 소리도 함께 남겨 맞는지 본다
    private static let speechLevel: Float = 0.01

    private let state = Mutex(State())

    var listening: Bool {
        get { state.withLock { $0.listening } }
        set {
            state.withLock {
                // 새로 듣기 시작할 때 소리 기록을 비우고 수음 강도를 설정값으로 맞춘다
                if newValue, !$0.listening {
                    $0.lastLoudAt = nil
                    $0.maxLevel = 0
                    $0.maxBlockedLevel = 0
                    $0.held = nil
                    $0.gate = MicGate(threshold: MicGate.savedThreshold)
                }
                $0.listening = newValue
            }
        }
    }

    /// 이번 턴에서 마지막으로 말소리가 들린 시각과 가장 컸던 소리
    var lastLoudAt: ContinuousClock.Instant? { state.withLock { $0.lastLoudAt } }
    var maxLevel: Float { state.withLock { $0.maxLevel } }
    var maxBlockedLevel: Float { state.withLock { $0.maxBlockedLevel } }

    func configure(converter: AnalyzerInputConverter, continuation: AsyncStream<AnalyzerInput>.Continuation) {
        state.withLock {
            $0.converter = converter
            $0.continuation = continuation
        }
    }

    /// 듣는 중일 때만 분석기로 넘긴다. 수음 강도 기준보다 작은 소리는 무음으로 바꿔 넘긴다
    /// (빼 버리지 않고 무음을 넣어야 인식기가 말이 끝난 것을 안다)
    func send(_ buffer: AVReadOnlyAudioPCMBuffer) {
        state.withLock { s in
            guard s.listening else { return }
            let copy = AVAudioPCMBuffer(copying: buffer)
            s.format = copy.format
            // 크기를 잴 수 없는 형식이면 거르지 않는다
            guard let level = Self.level(of: copy) else { return s.yield(copy) }
            if level > Self.speechLevel { s.lastLoudAt = .now }
            if s.gate.passes(level: level, at: .now) {
                s.maxLevel = max(s.maxLevel, level)
                if let held = s.held { s.yield(held.buffer) }
                s.held = nil
                s.yield(copy)
            } else {
                if let held = s.held {
                    s.maxBlockedLevel = max(s.maxBlockedLevel, held.level)
                    Self.mute(held.buffer)
                    s.yield(held.buffer)
                }
                s.held = (copy, level)
            }
        }
    }

    /// 무음 4초를 한꺼번에 넣는다. 말이 끝난 뒤의 문장 확정은 무음이 1~3초 들어가야 온다 (실기기 2026-11-14)
    func flush() {
        state.withLock { s in
            s.held = nil
            guard let format = s.format, let quiet = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate / 10)) else { return }
            quiet.frameLength = quiet.frameCapacity
            Self.mute(quiet)
            for _ in 0..<40 { s.yield(quiet) }
        }
    }

    func finish() {
        state.withLock { $0.continuation?.finish() }
    }

    private static func mute(_ buffer: AVAudioPCMBuffer) {
        guard let samples = buffer.floatChannelData else { return }
        for channel in 0..<Int(buffer.format.channelCount) {
            memset(samples[channel], 0, Int(buffer.frameLength) * MemoryLayout<Float>.size)
        }
    }

    /// 첫 채널의 소리 크기(RMS). 실수 형식이 아니면 재지 않는다
    private static func level(of buffer: AVAudioPCMBuffer) -> Float? {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return nil }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
        return (sum / Float(buffer.frameLength)).squareRoot()
    }
}
