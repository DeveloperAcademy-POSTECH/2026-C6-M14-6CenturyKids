//
//  PainRecordWithLocationsDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/18/26.
//

import Foundation

struct PainRecordWithLocationsDTO: Decodable {
    let id: UUID
    let patientId: UUID
    let occurredAt: Date
    let painBefore: Int
    let painAfter: Int
    let locations: [PainLocationDTO]
    
    func toDomain() throws -> PainRecord {
        let location: [BodyLocation] = try locations.map { try $0.toDomain() }
        
        return try PainRecord(id: id, patientId: patientId, recordedDate: occurredAt, location: location, painBefore: painBefore, painAfter: painAfter)
    }
}

extension PainRecordWithLocationsDTO {
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case patientId = "patient_id"
        case occurredAt = "occurred_at"
        case painBefore = "pain_before"
        case painAfter = "pain_after"
        case locations
    }
}
