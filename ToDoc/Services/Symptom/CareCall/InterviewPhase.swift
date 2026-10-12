//
//  InterviewPhase.swift
//  ToDoc
//
//  Created by seokho on 10/12/26.
//

/// 케어콜 대화 단계: 첫 질문 → 항목별 질문(slot) → 그 밖에(other) → 마무리(saved). 응급이면 바로 emergencyEnded
enum InterviewPhase: Equatable, Sendable {
    case opening
    case slot(key: String, step: CareCallStep)
    case other
    case saved
    case emergencyEnded

    var slotKey: String? { if case .slot(let key, _) = self { key } else { nil } }
}
