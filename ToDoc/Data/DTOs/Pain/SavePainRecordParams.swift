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
    let pPainAfter: Int
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
}
