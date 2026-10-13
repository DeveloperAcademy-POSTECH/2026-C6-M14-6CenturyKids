//
//  SpeechAnalyzerAdapter.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import AVFAudio
import Speech
import Synchronization

/// SpeechAnalyzer 한국어 음성 인식. 마이크(AudioRecorder) 소리를 기기 안에서 글자로 바꾼다.
/// 통화 동안 분석기 하나를 계속 돌리고, 듣는 중이 아닐 때(AI가 말하는 동안·정지 후) 들어온 소리는 버린다.
final class SpeechAnalyzerAdapter: SpeechRecognizer {
    /// 확정 결과 뒤 이만큼 새 결과가 없으면 말이 끝난 것으로 본다
    private static let silence: Duration = .seconds(1)

    private let recorder: AudioRecorder
    private let feed = AnalyzerFeed()
    private var analyzer: SpeechAnalyzer?
    private var resultsTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?
    /// 이번 턴에 확정된 문장
    private var finalized = ""
    private var turnEnd: CheckedContinuation<String, Never>?
    private var micOn = false

    init(recorder: AudioRecorder) {
        self.recorder = recorder
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

    func listen() async throws -> String {
        // 준비 전이나 정지 후에는 들을 수 없으니 바로 빈 문장을 돌려준다 (영원히 기다리지 않게)
        guard analyzer != nil else { return "" }
        // 마이크는 준비 때가 아니라 처음 들을 때 켠다 (준비 화면에서 마이크 표시가 켜지지 않게)
        if !micOn {
            try recorder.start { [feed] buffer in feed.send(buffer) }
            micOn = true
        }
        finalized = ""
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
        guard isFinal else { return }
        let sentence = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sentence.isEmpty { finalized = finalized.isEmpty ? sentence : finalized + " " + sentence }
        // 잡음만 들렸으면(확정 문장 없음) 계속 듣는다
        guard !finalized.isEmpty else { return }
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.silence)
            guard !Task.isCancelled else { return }
            self?.finishTurn()
        }
    }

    private func finishTurn() {
        feed.listening = false
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
    }

    private let state = Mutex(State())

    var listening: Bool {
        get { state.withLock { $0.listening } }
        set { state.withLock { $0.listening = newValue } }
    }

    func configure(converter: AnalyzerInputConverter, continuation: AsyncStream<AnalyzerInput>.Continuation) {
        state.withLock {
            $0.converter = converter
            $0.continuation = continuation
        }
    }

    /// 듣는 중일 때만 분석기 형식으로 바꿔 넘긴다
    func send(_ buffer: AVReadOnlyAudioPCMBuffer) {
        state.withLock { s in
            guard s.listening, let converter = s.converter,
                  let inputs = try? converter.convert(AVAudioPCMBuffer(copying: buffer), at: nil) else { return }
            for input in inputs { s.continuation?.yield(input) }
        }
    }

    func finish() {
        state.withLock { $0.continuation?.finish() }
    }
}
