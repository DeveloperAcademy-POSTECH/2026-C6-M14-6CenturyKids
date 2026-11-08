//
//  GeneratedPresence.swift
//  ToDoc
//
//  Created by seokho on 10/12/26.
//

import FoundationModels

/// 모델이 고르는 증상 유무. 엔진은 MentionPresence만 안다.
/// 모를 때는 지시문 규칙 2대로 mentions를 비우고 되묻게 해서 '모름'(unclear)은 고르지 않는다 ('모르겠어요' 답은 엔진이 따로 기록).
/// unclear를 두면 Foundation Models가 증상을 unclear로 적고 되물어 기타 증상을 놓쳤다 (2026-10-21 평가: 빼면 기타 증상 7/8 → 8/8, 되묻기 12 → 7)
@Generable
enum GeneratedPresence {
    case present, absent

    var mentionPresence: MentionPresence {
        switch self {
        case .present: .present
        case .absent: .absent
        }
    }
}
