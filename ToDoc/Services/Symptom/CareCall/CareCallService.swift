//
//  CareCallService.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation

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
    }
    private var conversation: Conversation?
    private var noticed = false
    private let minimumThinking: Duration = .seconds(5)

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
        let engine = InterviewEngine(config: config, rules: rules, analyzer: analyzer, followUp: previous.map(converter.unasked(in:)),
                                     locationWords: converter.bodyParts.parts.values.flatMap { $0 })
        let conversation = Conversation(engine: engine, patientId: patientId, followUp: previous != nil)
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
        case .saved: .completed(record(of: conversation))
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
            let text = try await recognizer.listen { onActivity(.hearing($0)) }
            guard !stopped, !text.isEmpty else { break }
            onActivity(.heard(text))
            let thinkingEnds = ContinuousClock.now.advanced(by: minimumThinking)
            out = await engine.handle(patientText: text)
            if let completion = out.answerCompletion { onActivity(.answerCompleted(completion)) }
            guard !stopped else { break }
            if out.phase != .emergencyEnded, engine.analyzedLastTurn {
                try await Task.sleep(until: thinkingEnds, clock: .continuous)
                guard !stopped else { break }
            }
            onActivity(.speaking(out.utterance))
            await voice.speak(out.utterance)
            await voice.waitUntilDone()
        }
        return out.phase
    }

    private func finish() async {
        recorder.onEvent = nil
        await recognizer.stop()
    }
}
