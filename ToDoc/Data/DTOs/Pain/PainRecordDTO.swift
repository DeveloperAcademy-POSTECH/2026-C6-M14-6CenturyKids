//
//  PainRecordDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/16/26.
//

import Foundation

struct PainRecordDTO: Codable {
    let id: UUID
    let patientId: UUID
    let occurredAt: Date
    let painBefore: Int
    let painAfter: Int
    
    init(painRecord: PainRecord) {
        id = painRecord.id
        patientId = painRecord.patientId
        occurredAt = painRecord.recordedDate
        painBefore = painRecord.painBefore
        painAfter = painRecord.painAfter
    }
    
    func toDomain(locations: [BodyLocation]) throws -> PainRecord {
        return try PainRecord(id: id, patientId: patientId, recordedDate: occurredAt, location: locations, painBefore: painBefore, painAfter: painAfter)
    }
}

extension PainRecordDTO {
    enum CodingKeys: String, CodingKey {
            case id = "id"
            case patientId = "patient_id"
            case occurredAt = "occurred_at"
            case painBefore = "pain_before"
            case painAfter = "pain_after"
    }
}
