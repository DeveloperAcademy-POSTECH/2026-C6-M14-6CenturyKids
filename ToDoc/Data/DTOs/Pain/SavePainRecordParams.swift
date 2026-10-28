//
//  SavePainRecordParams.swift
//  ToDoc
//
//  Created by 앤디 on 10/18/26.
//

import Foundation

struct SavePainRecordParams: Encodable {
    let pId: UUID
    let pPatientId: UUID
    let pOccurredAt: Date
    let pPainBefore: Int
    let pPainAfter: Int?
    let pLocations: [PainLocationParam]
}

extension SavePainRecordParams {
    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pPatientId = "p_patient_id"
        case pOccurredAt = "p_occurred_at"
        case pPainBefore = "p_pain_before"
        case pPainAfter = "p_pain_after"
        case pLocations = "p_locations"
    }

    /// 기본 인코딩은 nil인 값을 키째 빼서, 서버가 p_pain_after 없는 함수를 찾다가 실패합니다.
    /// 먹기 전 통증만 저장할 때도 p_pain_after를 null로 보냅니다.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pPatientId, forKey: .pPatientId)
        try container.encode(pOccurredAt, forKey: .pOccurredAt)
        try container.encode(pPainBefore, forKey: .pPainBefore)
        try container.encode(pPainAfter, forKey: .pPainAfter)
        try container.encode(pLocations, forKey: .pLocations)
    }
}
