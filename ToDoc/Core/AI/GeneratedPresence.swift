//
//  GeneratedPresence.swift
//  ToDoc
//
//  Created by seokho on 10/12/26.
//

import FoundationModels

/// 모델이 고르는 증상 유무. 엔진은 MentionPresence만 안다.
/// 이름·케이스는 프롬프트 v13을 평가한 출력 형식 그대로 둔다.
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
