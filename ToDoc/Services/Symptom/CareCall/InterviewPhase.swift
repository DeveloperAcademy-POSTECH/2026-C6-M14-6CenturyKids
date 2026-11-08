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

    /// 환자 답을 기다리는 질문 단계 (횟수·시작 시점 질문은 답을 그대로 적으므로 제외)
    var asksQuestion: Bool {
        switch self {
        case .opening, .other, .slot(_, .presence), .slot(_, .location): true
        case .slot(_, .detail), .saved, .emergencyEnded: false
        }
    }
}
