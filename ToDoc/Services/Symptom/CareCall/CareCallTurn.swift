//
//  CareCallTurn.swift
//  ToDoc
//
//  Created by seokho on 10/15/26.
//

/// 문자 대화 한 차례: AI가 한 말과 받을 답의 종류. 대화가 끝났으면 결과도 담는다
struct CareCallTurn: Sendable {
    let utterance: String
    /// 숫자로 받을 답 (횟수). nil이면 글자로 받는다
    let number: CareCallConfig.Effect.Detail.Number?
    let outcome: CareCallOutcome?
    /// 대화 진행 정도 (0~1)
    var progress: Double? = nil
    /// 말한 증상을 더 묻는 꼬리질문 (횟수·시작 시점·부위)
    var asksMore = false
    /// 마지막으로 묻는 질문 ('그 밖에'). 답에 새 증상이 있으면 더 물을 수 있다
    var isLast = false
}
