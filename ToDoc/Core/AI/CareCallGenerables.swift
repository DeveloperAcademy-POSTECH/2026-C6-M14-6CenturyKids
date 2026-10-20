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
    /// 엔진은 읽지 않지만 빼지 않는다: 빼면 실신 응급을 놓친 실행이 나왔고 속도 이득은 0.04초였다 (2026-10-19 Mac 평가)
    var answeredCurrentSlot: Bool
    var needsClarification: Bool
    var emergencySignal: Bool
    /// 설명을 달지 않는다: 언제 쓰는지(되물을 때만)는 지시문 규칙 6이 정한다. 예전 설명("다음에 환자에게 할 말")은 규칙 6과 어긋나
    /// 일부 실행에서 기록을 utterance에 쓰고 mentions를 비웠고("오심·구토: present"), "되물을 때만 쓰는 질문"은 질문 남발을 불렀다
    /// (2026-10-19 Mac 평가, 시나리오 55개×3회를 프로세스 3번씩)
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
