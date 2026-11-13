//
//  CareCallService.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation
import os

final class CareCallService: CareCalling {
    private let config: CareCallConfig
    private let converter: SymptomRecordConverter
    private let rules: EmergencyRules
    private let recorder: AudioRecorder
    private let recognizer: SpeechRecognizer
    private let voice: SpeechSynthesizer
    private let loadAnalyzer: () async throws -> CareCallAI
    private var analyzer: CareCallAI?
    private var stopped = false
    private struct Conversation {
        let engine: InterviewEngine
        let patientId: UUID
        let followUp: Bool
        /// 시연: 처음 통화에서 물을 3개와 목데이터
        let demo: DemoCareCallPlan?
    }
    private var conversation: Conversation?
    private var noticed = false
    /// 듣는 말이 이만큼 그대로면 말을 멈춘 것으로 보고 분석을 미리 시작한다 (관리자 설정에서 켰을 때)
    private static let speculationPause: Duration = .milliseconds(700)
    private var speculationDebounce: Task<Void, Never>?
    /// 미리 분석을 시작한 말
    private var speculatedText: String?

    init(config: CareCallConfig, rules: EmergencyRules, bodyParts: BodyPartDictionary, recorder: AudioRecorder, recognizer: SpeechRecognizer,
         voice: SpeechSynthesizer, loadAnalyzer: @escaping () async throws -> CareCallAI) {
        self.config = config
        self.converter = SymptomRecordConverter(config: config, bodyParts: bodyParts)
        self.rules = rules
        self.recorder = recorder
        self.recognizer = recognizer
        self.voice = voice
        self.loadAnalyzer = loadAnalyzer
    }

    func requestMicrophone() async throws {
        _ = try await recorder.prepare()
    }

    func loadModel() async throws {
        if analyzer == nil { analyzer = try await loadAnalyzer() }
    }

    func prepareSpeech() async throws {
        try await recognizer.prepare()
    }

    func begin(patientId: UUID, previous: SymptomRecord?) throws -> CareCallTurn {
        guard let analyzer else { throw CareCallServiceError.notPrepared }
        // 시연: 관리자 설정에서 켜 두면 그날 처음 통화는 3개만 랜덤으로 묻는다 (다시 거는 통화는 그대로)
        let demo = previous == nil && DemoCareCallPlan.isEnabled ? DemoCareCallPlan(effectIds: config.effects.map(\.id)) : nil
        let engine = InterviewEngine(config: config, rules: rules, analyzer: analyzer, followUp: previous.map(converter.unasked(in:)),
                                     askOnly: demo?.asked, locationWords: converter.bodyParts.parts.values.flatMap { $0 })
        let conversation = Conversation(engine: engine, patientId: patientId, followUp: previous != nil, demo: demo)
        self.conversation = conversation
        noticed = false
        return turn(conversation.engine.start(), of: conversation)
    }

    var voiceOpening: String? {
        conversation.map { noticed ? $0.engine.lastQuestion : config.aiVoiceNotice + " " + $0.engine.lastQuestion }
    }

    var current: CareCallTurn? {
        conversation.map { turn(InterviewEngine.Output(utterance: $0.engine.lastQuestion, phase: $0.engine.phase), of: $0) }
    }

    var appliedAnswerRevisions: Set<UUID>? {
        conversation?.engine.appliedAnswerRevisions
    }

    var progress: SymptomRecord? {
        conversation.flatMap(partialRecord(of:))
    }

    func answer(_ text: String) async throws -> CareCallTurn {
        guard let conversation else { throw CareCallServiceError.notPrepared }
        let out = await conversation.engine.handle(patientText: text)
        return turn(out, of: conversation)
    }

    var canGoBack: Bool {
        conversation?.engine.canGoBack ?? false
    }

    func back() -> (turn: CareCallTurn, answer: String)? {
        guard let conversation, let back = conversation.engine.goBack() else { return nil }
        return (turn(back.output, of: conversation), back.answer)
    }

    func continueAfterEmergency() -> CareCallTurn? {
        guard let conversation, let out = conversation.engine.continueAfterEmergency() else { return nil }
        return turn(out, of: conversation)
    }

    func end() -> CareCallOutcome {
        defer { conversation = nil }
        guard let conversation else { return .interrupted(nil) }
        return outcome(of: conversation, phase: conversation.engine.phase)
    }

    private func turn(_ out: InterviewEngine.Output, of conversation: Conversation) -> CareCallTurn {
        CareCallTurn(utterance: out.utterance, number: conversation.engine.expectedNumber,
                     outcome: out.isFinished ? outcome(of: conversation, phase: out.phase) : nil,
                     progress: conversation.engine.progress, asksMore: conversation.engine.asksMore,
                     isLast: conversation.engine.phase == .other,
                     questionID: conversation.engine.currentQuestionID, answerCompletion: out.answerCompletion)
    }

    private func outcome(of conversation: Conversation, phase: InterviewPhase) -> CareCallOutcome {
        switch phase {
        // 시연: 끝까지 마친 통화에만 묻지 않은 항목의 목데이터를 더한다
        case .saved: .completed(conversation.demo.map { $0.filling(record(of: conversation), touched: Set(conversation.engine.ledger.order)) } ?? record(of: conversation))
        case .emergencyEnded: .emergencyEnded(record(of: conversation))
        default: .interrupted(partialRecord(of: conversation))
        }
    }

    private func record(of conversation: Conversation) -> SymptomRecord {
        converter.record(from: conversation.engine.ledger, patientId: conversation.patientId, date: Date(), followUp: conversation.followUp)
    }

    private func partialRecord(of conversation: Conversation) -> SymptomRecord? {
        let record = record(of: conversation)
        return record.symptoms.isEmpty ? nil : record
    }

    func run(onActivity: @escaping (CareCallActivity) -> Void) async throws -> CareCallOutcome {
        guard let conversation else { throw CareCallServiceError.notPrepared }
        stopped = false
        recorder.onEvent = { [weak self] event in
            if case .resumed = event { return }
            Task { await self?.stop() }
        }
        let phase: InterviewPhase
        do {
            phase = try await withTaskCancellationHandler {
                try await converse(engine: conversation.engine, onActivity: onActivity)
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

    func stop() async {
        stopped = true
        voice.stop()
        await recognizer.stop()
    }

    private func converse(engine: InterviewEngine, onActivity: @escaping (CareCallActivity) -> Void) async throws -> InterviewPhase {
        var out = InterviewEngine.Output(utterance: engine.lastQuestion, phase: engine.phase)
        let opening = voiceOpening ?? out.utterance
        noticed = true
        try recognizer.startMicrophone()
        onActivity(.speaking(opening))
        await voice.speak(opening)
        if engine.phase == .opening { await engine.prewarm() }
        await voice.waitUntilDone()

        while !out.isFinished, !stopped {
            onActivity(.listening)
            let text = try await recognizer.listen { [weak self] heard in
                onActivity(.hearing(heard))
                self?.speculate(on: heard, engine: engine)
            }
            speculationDebounce?.cancel()
            guard !stopped, !text.isEmpty else { break }
            onActivity(.heard(text))
            let heardAt = ContinuousClock.now
            out = await engine.handle(patientText: text)
            let handled = ContinuousClock.now - heardAt
            speculatedText = nil
            if await engine.cancelSpeculation() {
                FoundationModelsCareCallAdapter.timingLog.notice("[미리] 쓰이지 않음 (모델을 안 불렀거나 다른 요청)")
            }
            if !out.isFinished { await engine.prewarm() }
            if let completion = out.answerCompletion { onActivity(.answerCompleted(completion)) }
            guard !stopped else { break }
            FoundationModelsCareCallAdapter.timingLog.notice("""
                [턴] 답 처리 \(Int(handled / .milliseconds(1)), privacy: .public)ms · 말하기까지 \
                \(Int((ContinuousClock.now - heardAt) / .milliseconds(1)), privacy: .public)ms · 모델 \(engine.analyzedLastTurn ? "부름" : "안 부름", privacy: .public)
                """)
            onActivity(.speaking(out.utterance))
            await voice.speak(out.utterance)
            await voice.waitUntilDone()
        }
        return out.phase
    }

    /// 듣는 말이 바뀌면 미리 시작한 분석을 버리고, 말이 멈추면 그 말로 다시 시작한다.
    /// 문장이 확정되면 같은 말이 한 번 더 오는데, 그때는 그대로 둔다
    private func speculate(on heard: String, engine: InterviewEngine) {
        guard FoundationModelsCareCallAdapter.speculationEnabled else { return }
        let text = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != speculatedText else { return }
        speculationDebounce?.cancel()
        if let old = speculatedText {
            speculatedText = nil
            Task {
                guard await engine.cancelSpeculation() else { return }
                FoundationModelsCareCallAdapter.timingLog.notice(
                    "[미리] 말이 바뀜 · \(FoundationModelsCareCallAdapter.difference(old, text), privacy: .public)")
            }
        }
        guard !text.isEmpty else { return }
        speculationDebounce = Task { [weak self] in
            try? await Task.sleep(for: Self.speculationPause)
            guard !Task.isCancelled, let self else { return }
            self.speculatedText = text
            await engine.speculate(patientText: text)
        }
    }

    private func finish() async {
        recorder.onEvent = nil
        await recognizer.stop()
    }
}
