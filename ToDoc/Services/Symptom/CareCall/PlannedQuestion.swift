//
//  PlannedQuestion.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

/// SlotPlanner가 정한 다음 질문
enum PlannedQuestion: Equatable, Sendable {
    case slot(key: String, step: CareCallStep)
    case other
    /// 더 물을 것 없음 → 마무리
    case done
}
