//
//  CareCallGenerables.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//

import FoundationModels

/// 턴 분석 모델 출력 형식. 이름·설명은 프롬프트 v13을 평가한 형식 그대로 둔다.
@Generable
struct EffectMention {
    @Guide(description: "주요 부작용 ID 중 하나, 목록에 없으면 other")
    var effectId: String
    @Guide(description: "effectId가 other일 때 환자가 말한 증상 이름")
    var otherName: String?
    var presence: GeneratedPresence
    @Guide(description: "환자가 0~10 숫자로 직접 말한 경우에만 채움", .range(0...10))
    var severity: Int?
    @Guide(description: "환자가 직접 말한 부위만")
    var locations: [String]
    @Guide(description: "근거가 된 환자 발화 원문 그대로")
    var quote: String
}

@Generable
struct TurnAnalysis {
    var mentions: [EffectMention]
    var answeredCurrentSlot: Bool
    var needsClarification: Bool
    var emergencySignal: Bool
    @Guide(description: "다음에 환자에게 할 말. 존댓말, 짧게, 질문은 하나만")
    var utterance: String
}

extension TurnAnalysis {
    /// 엔진 타입으로 변환 (엔진은 FoundationModels를 모른다)
    var turnResult: TurnResult {
        TurnResult(
            mentions: mentions.map {
                Mention(effectId: $0.effectId, otherName: $0.otherName, presence: $0.presence.mentionPresence,
                        severity: $0.severity, locations: $0.locations, quote: $0.quote)
            },
            answeredCurrentSlot: answeredCurrentSlot,
            needsClarification: needsClarification,
            emergencySignal: emergencySignal,
            utterance: utterance)
    }
}
