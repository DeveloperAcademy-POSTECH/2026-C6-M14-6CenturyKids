//
//  FoundationModelsCareCallAdapter.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation
import FoundationModels
import os

/// CareCallAI의 기기 안 모델 구현 (Apple Intelligence 기본 모델). 호출마다 새 세션을 쓰고 Ledger 요약만 넣는다 (이전 대화 원문은 넣지 않음).
/// 분석에 쓰는 세션은 미리 데우지(prewarm) 않는다: 데운 세션으로 부르면 같은 요청인데 모델 답이 달라졌다
/// (2026-11-14 Mac 평가: 회귀 세트 요청 225개 중 23개, 통과 169 → 166, 보류 세트 92 → 91·91 → 73. 0.6초 빠른 대신 틀린 쪽은 전부 데운 쪽)
final class FoundationModelsCareCallAdapter: CareCallAI {
    /// 관리자 설정 토글이 저장하는 키. 값이 없으면 켜짐. 켜면 환자가 말을 멈춘 것 같을 때 문장 확정 전에 미리 분석한다
    static let speculationKey = "demo.fmSpeculate"
    static var speculationEnabled: Bool { UserDefaults.standard.object(forKey: speculationKey) as? Bool ?? true }
    static let timingLog = Logger(subsystem: "ToDoc", category: "FMTiming")

    /// 턴 분석 출력 상한. 넘으면 형식 실패로 엔진이 재시도한다. Foundation Models 평가(2026-10-21, 시나리오 55개): 상한 없음·100·160의
    /// 결과가 같고 60이면 79%가 잘림 → 정상 출력은 100토큰 아래. 항목을 늘어놓는 비정상 출력을 끊으려 여유를 두고 160
    private static let analysisMaxTokens = 160
    private static let promptName = "prompt-turn-analysis-v16"

    private let model: SystemLanguageModel
    private let template: PromptTemplate
    /// 횟수·시작 시점 단계(detail)는 엔진이 모델 없이 기록하므로 없다
    private let missingFieldNames: [CareCallStep: String] = [.presence: "유무", .location: "부위"]
    private var modelLoaded = false
    private var callNumber = 0
    /// 미리 시작한 분석: 그때의 프롬프트, 결과(첫 토큰·끝난 시각 포함), 시작 시각
    private var early: (prompt: String,
                        task: Task<(result: TurnResult, firstToken: ContinuousClock.Instant, finished: ContinuousClock.Instant), any Error>,
                        startedAt: ContinuousClock.Instant)?
    private var options: GenerationOptions {
        template.temperature == 0
            ? GenerationOptions(sampling: .greedy, maximumResponseTokens: Self.analysisMaxTokens)
            : GenerationOptions(temperature: template.temperature, maximumResponseTokens: Self.analysisMaxTokens)
    }

    init(model: SystemLanguageModel, bundle: Bundle = .main) throws {
        self.model = model
        self.template = try bundle.decodeJSON(PromptTemplate.self, named: Self.promptName)
    }

    func analyze(_ request: AnalysisRequest) async throws -> TurnResult {
        let text = prompt(for: request)
        if let result = await earlyResult(for: text) { return result }
        let session = LanguageModelSession(model: model, instructions: template.fullInstructions)
        callNumber += 1
        let start = ContinuousClock.now
        let (analysis, firstToken) = try await Self.respond(session: session, prompt: text, options: options)
        let total = ContinuousClock.now - start
        Self.timingLog.notice("""
            [FM #\(self.callNumber, privacy: .public)] 첫 토큰 \(ms(firstToken - start), privacy: .public)ms · 전체 \(ms(total), privacy: .public)ms · \
            지시문 \(self.template.fullInstructions.count, privacy: .public)자 · 프롬프트 \(text.count, privacy: .public)자
            """)
        return analysis.turnResult
    }

    /// 첫 분석 전에 모델을 메모리에 올려 둔다 (분석에는 쓰지 않는 세션으로, 한 번만)
    func prewarm() async {
        guard !modelLoaded else { return }
        modelLoaded = true
        LanguageModelSession(model: model, instructions: template.fullInstructions).prewarm()
    }

    func speculate(_ request: AnalysisRequest) async {
        let text = prompt(for: request)
        guard early?.prompt != text else { return }
        await cancelSpeculation()
        let session = LanguageModelSession(model: model, instructions: template.fullInstructions)
        let options = options
        let task = Task {
            let (analysis, firstToken) = try await Self.respond(session: session, prompt: text, options: options)
            return (result: analysis.turnResult, firstToken: firstToken, finished: ContinuousClock.now)
        }
        early = (text, task, .now)
        Self.timingLog.notice("[미리] 시작 · 프롬프트 \(text.count, privacy: .public)자")
    }

    @discardableResult func cancelSpeculation() async -> Bool {
        guard let old = early else { return false }
        early = nil
        old.task.cancel()
        let cancelled = ContinuousClock.now
        Self.timingLog.notice("[미리] 버림 · 시작 후 \(ms(cancelled - old.startedAt), privacy: .public)ms")
        // 버린 호출이 실제로 언제 멈추는지 (안 멈추면 다음 호출이 그 뒤에 줄을 선다)
        Task {
            _ = await old.task.result
            Self.timingLog.notice("[미리] 버린 호출 멈춤 · 취소 후 \(ms(ContinuousClock.now - cancelled), privacy: .public)ms")
        }
        return true
    }

    /// 미리 시작한 분석이 같은 프롬프트면 그 결과를 쓴다 (아직 돌고 있으면 끝날 때까지 기다린다). 다르면 버린다
    private func earlyResult(for text: String) async -> TurnResult? {
        guard let early else { return nil }
        guard early.prompt == text else {
            Self.timingLog.notice("[미리] 빗나감 · \(Self.difference(early.prompt, text), privacy: .public)")
            await cancelSpeculation()
            return nil
        }
        self.early = nil
        let asked = ContinuousClock.now
        guard let done = try? await early.task.value else {
            Self.timingLog.notice("[미리] 실패 · 다시 부름")
            return nil
        }
        Self.timingLog.notice("""
            [미리] 적중 · 시작 \(ms(asked - early.startedAt), privacy: .public)ms 뒤 요청 · 더 기다림 \(ms(ContinuousClock.now - asked), privacy: .public)ms · \
            첫 토큰 \(ms(done.firstToken - early.startedAt), privacy: .public)ms · 전체 \(ms(done.finished - early.startedAt), privacy: .public)ms
            """)
        return done.result
    }

    /// 미리 본 말과 나중 말이 어떻게 다른지 (내용은 남기지 않는다)
    static func difference(_ early: String, _ later: String) -> String {
        func letters(_ s: String) -> String { String(s.filter { $0.isLetter || $0.isNumber }) }
        if letters(early) == letters(later) { return "띄어쓰기·문장부호만 다름" }
        if letters(later).hasPrefix(letters(early)) { return "뒤에 말이 더 붙음" }
        return "글자가 다름"
    }

    private func prompt(for request: AnalysisRequest) -> String {
        template.render([
            "question": request.question,
            "effectId": request.slotKey ?? "없음",
            "effectName": request.slotName ?? "컨디션·기타 증상 전반",
            "missingFields": request.step.flatMap { missingFieldNames[$0] } ?? "언급된 증상 전부",
            "ledgerSummary": request.ledgerSummary,
            "patientText": request.patientText,
        ])
    }

    /// 기본 격리가 MainActor이고 `respond`는 부른 쪽에서 실행되므로, @concurrent로 추론을 메인 스레드 밖에서 돌린다.
    /// 첫 토큰 시각을 재려고 스트림으로 받는다 (그리디라 출력은 respond와 같다)
    @concurrent
    private nonisolated static func respond(session: LanguageModelSession, prompt: String,
                                            options: GenerationOptions) async throws -> (TurnAnalysis, ContinuousClock.Instant) {
        let stream = session.streamResponse(to: prompt, generating: TurnAnalysis.self, options: options)
        var firstToken: ContinuousClock.Instant?
        for try await _ in stream where firstToken == nil { firstToken = .now }
        let content = try await stream.collect().content
        return (content, firstToken ?? .now)
    }
}

private func ms(_ duration: Duration) -> Int {
    Int(duration / .milliseconds(1))
}
