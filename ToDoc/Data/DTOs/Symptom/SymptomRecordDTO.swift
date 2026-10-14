//
//  SymptomRecordDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/13/26.
//

import Foundation

struct SymptomRecordDTO: Codable {
    let id: UUID
    let patientId: UUID
    let date: String
    let recordedAt: Date
    
    init(symptomRecord: SymptomRecord) {
        id = symptomRecord.id
        patientId = symptomRecord.patientId
        date = DateOnlyFormatter.string(from: symptomRecord.recordedDate)
        recordedAt = symptomRecord.recordedDate
    }
    
    func toDomain(symptoms: [SymptomEntry]) -> SymptomRecord {
        return SymptomRecord(id: id, patientId: patientId, recordedDate: recordedAt, symptoms: symptoms)
    }
}

extension SymptomRecordDTO {
    enum CodingKeys: String, CodingKey {
            case id = "id"
            case patientId = "patient_id"
            case date = "date"
            case recordedAt = "recorded_at"
    }
}
