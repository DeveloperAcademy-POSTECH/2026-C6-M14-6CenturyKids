//
//  CareCallGenerables.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//

import FoundationModels

/// 턴 분석 모델 출력 형식. 이름·설명은 프롬프트를 평가한 형식 그대로 둔다.
@Generable
struct EffectMention {
    @Guide(description: "주요 부작용 ID 중 하나, 목록에 없으면 other")
    var effectId: String
    @Guide(description: "effectId가 other일 때 환자가 말한 증상 이름")
    var otherName: String?
    var presence: GeneratedPresence
    @Guide(description: "환자가 직접 말한 부위만")
    var locations: [String]
    @Guide(description: "근거가 된 환자 발화 원문 그대로")
    var quote: String
}

@Generable
struct TurnAnalysis {
    var mentions: [EffectMention]
    /// 엔진은 읽지 않지만 빼지 않는다: 빼면 통과가 47/55 → 42/55로 떨어졌다 (2026-10-21 Foundation Models 평가)
    var answeredCurrentSlot: Bool
    var needsClarification: Bool
    var emergencySignal: Bool
    /// 설명을 달지 않는다: 언제 쓰는지(되물을 때만)는 지시문 규칙 6이 정한다. 규칙 6에 맞춘 설명("needsClarification이 true일 때만…")을 달면
    /// 통과 47/55 → 45/55, 재현율 51/56 → 46/56으로 떨어졌다 (2026-10-21 Foundation Models 평가)
    var utterance: String
}

extension TurnAnalysis {
    /// 엔진 타입으로 변환 (엔진은 FoundationModels를 모른다)
    var turnResult: TurnResult {
        TurnResult(
            mentions: mentions.map {
                Mention(effectId: $0.effectId, otherName: $0.otherName, presence: $0.presence.mentionPresence,
                        locations: $0.locations, quote: $0.quote)
            },
            answeredCurrentSlot: answeredCurrentSlot,
            needsClarification: needsClarification,
            emergencySignal: emergencySignal,
            utterance: utterance)
    }
}
