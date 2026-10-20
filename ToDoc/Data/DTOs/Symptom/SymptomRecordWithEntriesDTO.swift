//
//  SymptomRecordWithEntriesDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/19/26.
//

import Foundation

struct SymptomRecordWithEntriesDTO: Decodable {
    let id: UUID
    let patientId: UUID
    let date: String
    let recordedAt: Date
    let condition: String?
    let entries: [SymptomEntryDTO]
    
    func toDomain() throws -> SymptomRecord {
        let symptoms: [SymptomEntry] = try entries.map { try $0.toDomain() }
        
        return SymptomRecord(id: id, patientId: patientId, recordedDate: recordedAt, conditionText: condition, symptoms: symptoms)
    }
}

extension SymptomRecordWithEntriesDTO {
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case patientId = "patient_id"
        case date = "date"
        case recordedAt = "recorded_at"
        case condition = "condition"
        case entries
    }
}
