//
//  SaveSymptomRecordParams.swift
//  ToDoc
//
//  Created by 앤디 on 10/19/26.
//

import Foundation

struct SaveSymptomRecordParams: Encodable {
    let pId: UUID
    let pPatientId: UUID
    let pDate: String
    let pRecordedAt: Date
    let pCondition: String?
    let pSymptoms: [SymptomEntryParam]
}

extension SaveSymptomRecordParams {
    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pPatientId = "p_patient_id"
        case pDate = "p_date"
        case pRecordedAt = "p_recorded_at"
        case pCondition = "p_condition"
        case pSymptoms = "p_symptoms"
    }
}
