//
//  CareCallTurn.swift
//  ToDoc
//
//  Created by seokho on 10/15/26.
//

/// 문자 대화 한 차례: AI가 한 말과 받을 답의 종류. 대화가 끝났으면 결과도 담는다
struct CareCallTurn: Sendable {
    let utterance: String
    /// 숫자로 받을 답 (횟수·지속 시간). nil이면 글자로 받는다
    let number: CareCallConfig.Effect.Detail.Number?
    let outcome: CareCallOutcome?
}
