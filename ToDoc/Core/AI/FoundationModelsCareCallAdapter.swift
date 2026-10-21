//
//  FoundationModelsCareCallAdapter.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation
import FoundationModels

/// CareCallAI의 기기 안 모델 구현 (Apple Intelligence 기본 모델). 호출마다 새 세션을 만들고 Ledger 요약만 넣는다 (이전 대화 원문은 넣지 않음).
final class FoundationModelsCareCallAdapter: CareCallAI {
    /// 턴 분석 출력 상한. 넘으면 형식 실패로 엔진이 재시도한다. Foundation Models 평가(2026-10-21, 시나리오 55개): 상한 없음·100·160의
    /// 결과가 같고 60이면 79%가 잘림 → 정상 출력은 100토큰 아래. 항목을 늘어놓는 비정상 출력을 끊으려 여유를 두고 160
    private static let analysisMaxTokens = 160
    private static let promptName = "prompt-turn-analysis-v16"

    private let model: SystemLanguageModel
    private let template: PromptTemplate
    /// 횟수·시작 시점 단계(detail)는 엔진이 모델 없이 기록하므로 없다
    private let missingFieldNames: [CareCallStep: String] = [.presence: "유무", .location: "부위"]

    init(model: SystemLanguageModel, bundle: Bundle = .main) throws {
        self.model = model
        self.template = try bundle.decodeJSON(PromptTemplate.self, named: Self.promptName)
    }

    func analyze(_ request: AnalysisRequest) async throws -> TurnResult {
        let options = template.temperature == 0
            ? GenerationOptions(sampling: .greedy, maximumResponseTokens: Self.analysisMaxTokens)
            : GenerationOptions(temperature: template.temperature, maximumResponseTokens: Self.analysisMaxTokens)
        return try await Self.respond(model: model, instructions: template.fullInstructions,
                                      prompt: prompt(for: request), options: options).turnResult
    }

    /// 첫 분석 전에 모델을 메모리에 올려 둔다
    func prewarm(_ request: AnalysisRequest) async {
        LanguageModelSession(model: model, instructions: template.fullInstructions).prewarm()
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
    @concurrent
    private nonisolated static func respond(model: SystemLanguageModel, instructions: String, prompt: String,
                                            options: GenerationOptions) async throws -> TurnAnalysis {
        let session = LanguageModelSession(model: model, instructions: instructions)
        return try await session.respond(to: prompt, generating: TurnAnalysis.self, options: options).content
    }
}
