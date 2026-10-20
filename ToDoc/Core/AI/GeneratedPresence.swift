//
//  GeneratedPresence.swift
//  ToDoc
//
//  Created by seokho on 10/12/26.
//

import FoundationModels

/// 모델이 고르는 증상 유무. 엔진은 MentionPresence만 안다.
/// 이름·케이스는 프롬프트를 평가한 출력 형식 그대로 둔다.
/// unclear는 지시문 규칙 2(모르면 mentions를 비움) 때문에 모델이 고르지 않지만(평가 모델 호출 3,150회 중 0회) 빼지 않는다:
/// 빼도 나아지지 않았고, 형식을 바꾸면 출력 전체가 흔들린다 (2026-10-19 Mac 평가)
@Generable
enum GeneratedPresence {
    case present, absent, unclear

    var mentionPresence: MentionPresence {
        switch self {
        case .present: .present
        case .absent: .absent
        case .unclear: .unclear
        }
    }
}
