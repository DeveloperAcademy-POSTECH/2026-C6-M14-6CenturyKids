//
//  SlotPlanner.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//

import Foundation

/// 다음 질문은 Ledger 상태로만 정한다 (모델 출력으로 순서를 정하지 않음).
enum SlotPlanner {
    static func next(ledger: Ledger, config: CareCallConfig, otherAsked: Bool) -> PlannedQuestion {
        for effect in config.effects {
            if let step = pendingStep(ledger[effect.id], effect: effect) {
                return .slot(key: effect.id, step: step)
            }
        }
        guard otherAsked else { return .other }
        // 기타 부작용: 있음/없음이 불분명할 때만 다시 묻는다 (내용은 '그 밖에' 꼬리질문으로 그대로 기록, 부위는 묻지 않음)
        for key in ledger.order where key.hasPrefix("other:") {
            if let step = pendingStep(ledger[key], effect: nil) {
                return .slot(key: key, step: step)
            }
        }
        return .done
    }

    /// 아직 묻지 않은 꼬리질문 (구토·메스꺼움처럼 둘이면 차례로)
    static func pendingDetail(_ entry: Ledger.Entry, effect: CareCallConfig.Effect) -> CareCallConfig.Effect.Detail? {
        effect.details(heard: entry.quotes).first { detail in !entry.details.contains { $0.label == detail.label } }
    }

    /// 아직 확인할 단계. 있음이면 횟수·시작·지속 시간(detail) → 부위 순. 이미 있음/없음이 기록된 항목은 유무 단계를 건너뛴다.
    /// effect가 nil이면 기타 항목 (있음이면 더 묻지 않음)
    static func pendingStep(_ entry: Ledger.Entry?, effect: CareCallConfig.Effect?) -> CareCallStep? {
        guard let entry else { return .presence }
        if entry.closed || entry.unknownSteps.contains(.presence) { return nil }
        switch entry.presence {
        case nil, .unclear?: return .presence
        case .absent?: return nil
        case .present?:
            guard let effect else { return nil }
            if pendingDetail(entry, effect: effect) != nil { return .detail }
            if effect.requiresLocation && entry.locations.isEmpty && !entry.unknownSteps.contains(.location) { return .location }
            return nil
        }
    }
}
