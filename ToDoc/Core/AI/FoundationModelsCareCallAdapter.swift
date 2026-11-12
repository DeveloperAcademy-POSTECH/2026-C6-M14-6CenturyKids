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
/// 세션을 재사용하면 transcript가 쌓여 입력이 길어지므로, 쓰고 나면 바로 다음 호출용 세션을 만들어 prewarm해 둔다.
final class FoundationModelsCareCallAdapter: CareCallAI {
    /// 관리자 설정 토글이 저장하는 키. 값이 없으면 켜짐. 끄면 예전처럼 호출 때 세션을 만든다 (속도 비교용)
    static let warmSessionKey = "demo.fmWarmSession"
    static var warmSessionEnabled: Bool { UserDefaults.standard.object(forKey: warmSessionKey) as? Bool ?? true }
    static let timingLog = Logger(subsystem: "ToDoc", category: "FMTiming")

    /// 턴 분석 출력 상한. 넘으면 형식 실패로 엔진이 재시도한다. Foundation Models 평가(2026-10-21, 시나리오 55개): 상한 없음·100·160의
    /// 결과가 같고 60이면 79%가 잘림 → 정상 출력은 100토큰 아래. 항목을 늘어놓는 비정상 출력을 끊으려 여유를 두고 160
    private static let analysisMaxTokens = 160
    private static let promptName = "prompt-turn-analysis-v16"

    private let model: SystemLanguageModel
    private let template: PromptTemplate
    /// 횟수·시작 시점 단계(detail)는 엔진이 모델 없이 기록하므로 없다
    private let missingFieldNames: [CareCallStep: String] = [.presence: "유무", .location: "부위"]
    /// 미리 만들어 prewarm한 다음 호출용 세션, 데운 시각, 함께 데운 프롬프트 앞부분 (환자 답 앞까지)
    private var spare: (session: LanguageModelSession, warmedAt: ContinuousClock.Instant, prefix: String?)?
    private var callNumber = 0

    init(model: SystemLanguageModel, bundle: Bundle = .main) throws {
        self.model = model
        self.template = try bundle.decodeJSON(PromptTemplate.self, named: Self.promptName)
    }

    func analyze(_ request: AnalysisRequest) async throws -> TurnResult {
        let options = template.temperature == 0
            ? GenerationOptions(sampling: .greedy, maximumResponseTokens: Self.analysisMaxTokens)
            : GenerationOptions(temperature: template.temperature, maximumResponseTokens: Self.analysisMaxTokens)
        let warm = spare
        spare = nil
        let session = warm?.session ?? LanguageModelSession(model: model, instructions: template.fullInstructions)
        defer { if Self.warmSessionEnabled { prepareSpare(prefix: nil) } }
        callNumber += 1
        let text = prompt(for: request)
        let start = ContinuousClock.now
        let (analysis, firstToken) = try await Self.respond(session: session, prompt: text, options: options)
        let total = ContinuousClock.now - start
        let warmedAgo = warm.map { w in
            let prefix = w.prefix.map { text.hasPrefix($0) ? "앞부분 맞음" : "앞부분 다름" } ?? "앞부분 없음"
            return "\(ms(start - w.warmedAt))ms 전 데움(\(prefix))"
        } ?? "그 자리에서 만듦"
        Self.timingLog.notice("""
            [FM #\(self.callNumber, privacy: .public)] 첫 토큰 \(ms(firstToken - start), privacy: .public)ms · 전체 \(ms(total), privacy: .public)ms · \
            세션 \(warmedAgo, privacy: .public) · 지시문 \(self.template.fullInstructions.count, privacy: .public)자 · 프롬프트 \(text.count, privacy: .public)자
            """)
        return analysis.turnResult
    }

    /// 질문을 읽어 주는 동안 다음 분석용 세션을 데운다. 켜져 있으면 프롬프트의 환자 답 앞부분까지 함께 데운다
    func prewarm(_ request: AnalysisRequest) async {
        if Self.warmSessionEnabled {
            prepareSpare(prefix: prompt(for: request))
        } else {
            LanguageModelSession(model: model, instructions: template.fullInstructions).prewarm()
        }
    }

    private func prepareSpare(prefix: String?) {
        let session = LanguageModelSession(model: model, instructions: template.fullInstructions)
        session.prewarm(promptPrefix: prefix.map { Prompt($0) })
        spare = (session, .now, prefix)
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
