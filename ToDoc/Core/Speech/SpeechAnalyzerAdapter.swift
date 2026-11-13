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
    /// 듣기 구간 시간 로그 (Console에서 SpeechTiming). 말소리가 끝난 뒤 문장이 확정되고 턴이 끝나기까지를 잰다
    private static let timingLog = Logger(subsystem: "ToDoc", category: "SpeechTiming")

    private let recorder: AudioRecorder
    private let feed = AnalyzerFeed()
    private var analyzer: SpeechAnalyzer?
    private var resultsTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?
    /// 이번 턴에 확정된 문장
    private var finalized = ""
    /// 이번 턴에서 지금까지 들은 말을 받는 쪽 (중간 결과 포함)
    private var onPartial: ((String) -> Void)?
    private var turnEnd: CheckedContinuation<String, Never>?
    private var micOn = false
    /// 시간 로그용: 이번 턴의 마지막 중간 결과·마지막 확정 시각, 그 확정 때까지 마지막으로 말소리가 들린 시각, 확정 횟수
    private var lastPartialAt: ContinuousClock.Instant?
    private var finalAt: ContinuousClock.Instant?
    private var loudAtFinal: ContinuousClock.Instant?
    private var finals = 0

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

    func listen(onPartial: @escaping (String) -> Void) async throws -> String {
        // 준비 전이나 정지 후에는 들을 수 없으니 바로 빈 문장을 돌려준다 (영원히 기다리지 않게)
        guard analyzer != nil else { return "" }
        try startMicrophone()
        finalized = ""
        lastPartialAt = nil
        finalAt = nil
        loudAtFinal = nil
        finals = 0
        self.onPartial = onPartial
        feed.listening = true
        return await withCheckedContinuation { turnEnd = $0 }
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
        guard feed.listening else { return }
        // 새 결과가 왔다 = 아직 말하는 중이니 무음 타이머를 다시 잰다
        silenceTask?.cancel()
        let sentence = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 중간 결과는 확정 문장 뒤에 붙여 보여 주기만 한다 (말하는 동안 바뀔 수 있어 턴 문장에는 넣지 않는다)
        guard isFinal else {
            lastPartialAt = .now
            onPartial?(Self.joined(finalized, sentence))
            return
        }
        finalAt = .now
        loudAtFinal = feed.lastLoudAt
        finals += 1
        finalized = Self.joined(finalized, sentence)
        onPartial?(finalized)
        // 잡음만 들렸으면(확정 문장 없음) 계속 듣는다
        guard !finalized.isEmpty else { return }
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.silence)
            guard !Task.isCancelled else { return }
            self?.finishTurn()
        }
    }

    /// 턴이 끝날 때 한 줄: 말소리 끝 → 확정, 마지막 중간 결과 → 확정, 확정 → 턴 끝(무음 대기), 확정 횟수(2번 이상이면 말이 이어진 것)
    private func logTiming() {
        guard turnEnd != nil, let finalAt else { return }
        func gap(_ from: ContinuousClock.Instant?) -> String { from.map { "\(Int((finalAt - $0) / .milliseconds(1)))ms" } ?? "모름" }
        let wait = Int((ContinuousClock.now - finalAt) / .milliseconds(1))
        let level = String(format: "%.3f", feed.maxLevel)
        Self.timingLog.notice("""
            [듣기] 소리 끝→확정 \(gap(self.loudAtFinal), privacy: .public) · 마지막 중간 결과→확정 \(gap(self.lastPartialAt), privacy: .public) · \
            확정→턴 끝 \(wait, privacy: .public)ms · 확정 \(self.finals, privacy: .public)번 · 최대 소리 \(level, privacy: .public)
            """)
    }

    private static func joined(_ head: String, _ tail: String) -> String {
        head.isEmpty || tail.isEmpty ? head + tail : head + " " + tail
    }

    private func finishTurn() {
        logTiming()
        feed.listening = false
        onPartial = nil
        turnEnd?.resume(returning: finalized)
        turnEnd = nil
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
    }

    /// 이 크기(RMS)를 넘으면 말소리로 본다. 시간 로그용 어림값이라 턴마다 최대 소리도 함께 남겨 맞는지 본다
    private static let speechLevel: Float = 0.01

    private let state = Mutex(State())

    var listening: Bool {
        get { state.withLock { $0.listening } }
        set {
            state.withLock {
                // 새로 듣기 시작할 때 소리 기록을 비운다
                if newValue, !$0.listening { $0.lastLoudAt = nil; $0.maxLevel = 0 }
                $0.listening = newValue
            }
        }
    }

    /// 이번 턴에서 마지막으로 말소리가 들린 시각과 가장 컸던 소리
    var lastLoudAt: ContinuousClock.Instant? { state.withLock { $0.lastLoudAt } }
    var maxLevel: Float { state.withLock { $0.maxLevel } }

    func configure(converter: AnalyzerInputConverter, continuation: AsyncStream<AnalyzerInput>.Continuation) {
        state.withLock {
            $0.converter = converter
            $0.continuation = continuation
        }
    }

    /// 듣는 중일 때만 분석기 형식으로 바꿔 넘긴다
    func send(_ buffer: AVReadOnlyAudioPCMBuffer) {
        state.withLock { s in
            guard s.listening, let converter = s.converter else { return }
            let copy = AVAudioPCMBuffer(copying: buffer)
            if let level = Self.level(of: copy) {
                s.maxLevel = max(s.maxLevel, level)
                if level > Self.speechLevel { s.lastLoudAt = .now }
            }
            guard let inputs = try? converter.convert(copy, at: nil) else { return }
            for input in inputs { s.continuation?.yield(input) }
        }
    }

    func finish() {
        state.withLock { $0.continuation?.finish() }
    }

    /// 첫 채널의 소리 크기(RMS). 실수 형식이 아니면 재지 않는다
    private static func level(of buffer: AVAudioPCMBuffer) -> Float? {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return nil }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
        return (sum / Float(buffer.frameLength)).squareRoot()
    }
}
