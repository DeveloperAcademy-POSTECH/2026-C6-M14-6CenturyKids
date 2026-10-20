//
//  CoreAICareCallAdapter.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation
import FoundationModels

/// CareCallAI의 기기 안 모델 구현. 호출마다 새 세션을 만들고 Ledger 요약만 넣는다 (이전 대화 원문은 넣지 않음).
final class CoreAICareCallAdapter: CareCallAI {
    /// 턴 분석 출력 상한. 프로토타입 평가 377회: 중앙 65, 상위 5% 113, 상위 1% 223토큰.
    /// 200토큰을 넘는 출력은 항목을 늘어놓는 비정상 출력이었고 한 번에 10~24초 걸렸다. 넘으면 형식 실패로 엔진이 재시도한다.
    private static let analysisMaxTokens = 160
    private static let promptName = "prompt-turn-analysis-v14"

    private let model: any LanguageModel
    private let template: PromptTemplate
    /// 횟수·시작 시점 단계(detail)는 엔진이 모델 없이 기록하므로 없다
    private let missingFieldNames: [CareCallStep: String] = [.presence: "유무", .location: "부위"]

    init(model: any LanguageModel, bundle: Bundle = .main) throws {
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

    /// 같은 지시문으로 1토큰만 생성해 지시문 계산 결과(KV)를 남긴다 (CoreAILM fork의 접두 재사용 패치 전제).
    /// 출력이 잘려 형식 변환은 실패하므로 오류는 무시한다.
    func prewarm(_ request: AnalysisRequest) async {
        _ = try? await Self.respond(model: model, instructions: template.fullInstructions, prompt: prompt(for: request),
                                    options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 1))
    }

    private func prompt(for request: AnalysisRequest) -> String {
        template.render([
            "question": request.question,
            "effectName": request.slotName ?? "컨디션·기타 증상 전반",
            "missingFields": request.step.flatMap { missingFieldNames[$0] } ?? "언급된 증상 전부",
            "ledgerSummary": request.ledgerSummary,
            "patientText": request.patientText,
        ])
    }

    /// 기본 격리가 MainActor이고 `respond`는 부른 쪽에서 실행되므로, @concurrent로 추론을 메인 스레드 밖에서 돌린다.
    @concurrent
    private nonisolated static func respond(model: any LanguageModel, instructions: String, prompt: String,
                                            options: GenerationOptions) async throws -> TurnAnalysis {
        let session = LanguageModelSession(model: model, instructions: instructions)
        return try await session.respond(to: prompt, generating: TurnAnalysis.self, options: options).content
    }
}
