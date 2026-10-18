//
//  CareCallService.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation

/// 케어콜 음성 통화. 준비(마이크 권한 → 모델 → 한국어 인식) 뒤 엔진·음성 인식·음성 합성·AI 분석을 한 통화로 묶는다.
/// 끝나면 저장할 기록을 돌려주고, 저장은 부른 쪽이 한다. 통화가 끝나면 음성 인식을 닫으므로, 다시 걸려면 prepareSpeech()부터 다시 부른다.
final class CareCallService: CareCalling {
    /// 분석이 이보다 오래 걸리면 맞장구를 먼저 말한다 (바로 말하면 어색함, 프로토타입 기기 테스트)
    private static let acknowledgementDelay: Duration = .seconds(1)

    private let config: CareCallConfig
    private let converter: SymptomRecordConverter
    private let rules: EmergencyRules
    private let recorder: AudioRecorder
    private let recognizer: SpeechRecognizer
    /// 응급 안내를 읽는 시스템 음성 (Supertonic 라이선스상 의료 조언으로 볼 수 있는 문구는 Supertonic으로 읽지 않는다)
    private let systemVoice: SpeechSynthesizer
    /// 모델(약 2.4GB)과 Supertonic(약 0.9GB)은 앱 시작이 아니라 준비 단계에서 만든다
    private let loadAnalyzer: () async throws -> CareCallAI
    private let makeVoice: () -> SpeechSynthesizer
    private var analyzer: CareCallAI?
    private var voice: SpeechSynthesizer?
    private var stopped = false
    /// 지금 대화와 그 환자. 음성 통화와 문자 답이 같은 대화를 이어 간다
    private struct Conversation {
        let engine: InterviewEngine
        let patientId: UUID
        /// 같은 날 다시 거는 통화
        let followUp: Bool
    }
    private var conversation: Conversation?
    /// 지금 대화에서 AI 음성 안내를 했음 (문자로 시작해 음성으로 바꿔도 처음 말할 때 한 번은 알린다)
    private var noticed = false

    init(config: CareCallConfig, rules: EmergencyRules, bodyParts: BodyPartDictionary, recorder: AudioRecorder, recognizer: SpeechRecognizer,
         systemVoice: SpeechSynthesizer, loadAnalyzer: @escaping () async throws -> CareCallAI,
         makeVoice: @escaping () -> SpeechSynthesizer) {
        self.config = config
        self.converter = SymptomRecordConverter(config: config, bodyParts: bodyParts)
        self.rules = rules
        self.recorder = recorder
        self.recognizer = recognizer
        self.systemVoice = systemVoice
        self.loadAnalyzer = loadAnalyzer
        self.makeVoice = makeVoice
    }

    // MARK: - 준비 (차례로 부른다. 실패하면 같은 단계를 다시 부를 수 있다)

    /// 마이크 권한을 받고 오디오 세션을 연다
    func requestMicrophone() async throws {
        _ = try await recorder.prepare()
    }

    /// AI 모델과 음성 합성을 불러오고, 고정 문구를 뒤에서 미리 합성하기 시작한다
    func loadModel() async throws {
        if analyzer == nil { analyzer = try await loadAnalyzer() }
        if voice == nil {
            let voice = makeVoice()
            voice.preload(config.spokenPhrases(rules: rules))
            self.voice = voice
        }
    }

    /// 한국어 음성 인식을 준비한다 (처음 한 번 인식 에셋을 내려받는다). 마이크는 통화를 시작할 때 켜진다
    func prepareSpeech() async throws {
        try await recognizer.prepare()
    }

    // MARK: - 대화

    func begin(patientId: UUID, previous: SymptomRecord?) throws -> CareCallTurn {
        guard let analyzer else { throw CareCallServiceError.notPrepared }
        let engine = InterviewEngine(config: config, rules: rules, analyzer: analyzer, followUp: previous.map(converter.unasked(in:)))
        let conversation = Conversation(engine: engine, patientId: patientId, followUp: previous != nil)
        self.conversation = conversation
        noticed = false
        return turn(conversation.engine.start(), of: conversation)
    }

    var current: CareCallTurn? {
        conversation.map { turn(InterviewEngine.Output(utterance: $0.engine.lastQuestion, phase: $0.engine.phase), of: $0) }
    }

    func answer(_ text: String) async throws -> CareCallTurn {
        guard let conversation else { throw CareCallServiceError.notPrepared }
        // 문자 대화에서도 모델을 불러올 때 음성 합성이 고정 문구를 미리 합성하기 시작한다. 분석 중에는 멈춘다 (CPU 경쟁)
        await voice?.setBusy(true)
        let out = await conversation.engine.handle(patientText: text)
        await voice?.setBusy(false)
        return turn(out, of: conversation)
    }

    func end() -> CareCallOutcome {
        defer { conversation = nil }
        guard let conversation else { return .interrupted(nil) }
        return outcome(of: conversation, phase: conversation.engine.phase)
    }

    private func turn(_ out: InterviewEngine.Output, of conversation: Conversation) -> CareCallTurn {
        CareCallTurn(utterance: out.utterance, number: conversation.engine.expectedNumber,
                     outcome: out.isFinished ? outcome(of: conversation, phase: out.phase) : nil)
    }

    /// 마무리 인사까지 마쳤으면 그날 기록, 응급이면 응급 종료, 중간이면 끊긴 곳까지 답한 기록
    private func outcome(of conversation: Conversation, phase: InterviewPhase) -> CareCallOutcome {
        switch phase {
        case .saved: .completed(record(of: conversation))
        case .emergencyEnded: .emergencyEnded
        default: .interrupted(partialRecord(of: conversation))
        }
    }

    private func record(of conversation: Conversation) -> SymptomRecord {
        converter.record(from: conversation.engine.ledger, patientId: conversation.patientId, date: Date(), followUp: conversation.followUp)
    }

    /// 받은 답이 하나도 없으면 nil (빈 기록으로 그날 기록을 덮지 않게. 첫 질문 답만 있어도 저장하지 않는다)
    private func partialRecord(of conversation: Conversation) -> SymptomRecord? {
        let record = record(of: conversation)
        return record.symptoms.isEmpty ? nil : record
    }

    // MARK: - 통화

    /// 지금 대화를 끝까지 통화로 진행하고 결과를 돌려준다. 마무리 인사까지 마쳤으면 그날 기록, 중간에 끝났으면(stop·전화 등 오디오 중단, 통화 중 오류)
    /// 끊긴 곳까지 답한 기록. 통화 중 오류인데 받은 답이 없으면 오류를 그대로 던진다
    func run(onActivity: @escaping (CareCallActivity) -> Void) async throws -> CareCallOutcome {
        guard let conversation, let voice else { throw CareCallServiceError.notPrepared }
        stopped = false // 지난 통화를 stop으로 끝냈어도 다시 걸 수 있게
        // 전화·Siri로 오디오가 끊기면 통화를 끝낸다 (중간부터 이어 가지 않는다)
        recorder.onEvent = { [weak self] event in
            if case .resumed = event { return }
            Task { await self?.stop() }
        }
        let phase: InterviewPhase
        do {
            // 부른 쪽 작업이 취소되면(화면을 닫음) stop과 같이 끝낸다. 음성 인식은 취소를 직접 보지 않는다
            phase = try await withTaskCancellationHandler {
                try await converse(engine: conversation.engine, voice: voice, onActivity: onActivity)
            } onCancel: {
                Task { @MainActor [weak self] in await self?.stop() }
            }
        } catch {
            await finish()
            guard let partial = partialRecord(of: conversation) else { throw error }
            return .interrupted(partial)
        }
        await finish()
        return outcome(of: conversation, phase: phase)
    }

    /// 통화를 바로 끝낸다 (말하기·듣기 정지). 진행 중인 run은 중단 단계로 돌아온다
    func stop() async {
        stopped = true
        voice?.stop()
        systemVoice.stop()
        await recognizer.stop()
    }

    private func converse(engine: InterviewEngine, voice: SpeechSynthesizer,
                          onActivity: @escaping (CareCallActivity) -> Void) async throws -> InterviewPhase {
        var out = InterviewEngine.Output(utterance: engine.lastQuestion, phase: engine.phase)
        let opening = noticed ? out.utterance : config.aiVoiceNotice + " " + out.utterance
        noticed = true
        // 첫 질문을 말하는 동안 마이크를 미리 켠다: 바로 대답해도 말 앞부분을 놓치지 않고,
        // 엔진을 켤 때의 메인 스레드 멈춤(iPhone 17 약 0.3초)이 듣기 시작하는 순간이 아니라 AI가 말하기 전에 생긴다
        try recognizer.startMicrophone()
        onActivity(.speaking(opening))
        await voice.speak(opening)
        // 첫 질문을 말하는 동안 모델을 데운다. 듣기 전에 끝나므로 분석과 겹치지 않는다
        // (모델은 새 생성이 시작되면 진행 중인 생성을 취소한다). 문자로 이미 답했으면 데워져 있다
        if engine.phase == .opening { await engine.prewarm() }
        await voice.waitUntilDone()

        while !out.isFinished, !stopped {
            onActivity(.listening)
            let text = try await recognizer.listen()
            guard !stopped, !text.isEmpty else { break }
            onActivity(.heard(text))
            // 분석이 오래 걸리면 맞장구를 먼저 말한다. 그 전에 끝나면 말하지 않는다
            let acknowledgement = engine.acknowledgement(for: text).map { line in
                Task {
                    try? await Task.sleep(for: Self.acknowledgementDelay)
                    guard !Task.isCancelled, !stopped else { return }
                    onActivity(.speaking(line))
                    await voice.speak(line)
                }
            }
            await voice.setBusy(true) // 분석 중에는 고정 문구 미리 합성을 멈춘다 (CPU 경쟁)
            out = await engine.handle(patientText: text)
            await voice.setBusy(false)
            acknowledgement?.cancel()
            await acknowledgement?.value
            await voice.waitUntilDone() // 맞장구가 나오는 중이면 끝난 뒤 이어서
            guard !stopped else { break }
            let speaker = out.phase == .emergencyEnded ? systemVoice : voice
            onActivity(.speaking(out.utterance))
            await speaker.speak(out.utterance)
            await speaker.waitUntilDone()
        }
        return out.phase
    }

    /// 통화가 끝나면 마이크와 인식을 끈다
    private func finish() async {
        recorder.onEvent = nil
        await recognizer.stop()
    }
}
