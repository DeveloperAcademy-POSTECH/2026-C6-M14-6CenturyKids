//
//  PrevisitRecordDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/31/26.
//

import Foundation

struct PrevisitRecordDTO: Codable {
    let id: UUID
    let patientId: UUID
    let selectedDate: String
    let memo: String?
    let stateOfMind: String
    let submittedAt: Date
    
    init(previsitRecord: PrevisitRecord) {
        id = previsitRecord.id
        patientId = previsitRecord.patientId
        selectedDate = DateOnlyFormatter.string(from: previsitRecord.selectedDate)
        memo = previsitRecord.memo
        stateOfMind = previsitRecord.stateOfMind.rawValue
        submittedAt = previsitRecord.submittedAt
    }
    
    func toDomain() throws -> PrevisitRecord {
        guard let selectedDate = DateOnlyFormatter.date(from: selectedDate) else {
            throw MappingError.invalidSelectedDate(selectedDate)
        }
        
        guard let stateOfMind = StateOfMind(rawValue: stateOfMind) else {
            throw MappingError.invalidStateOfMind(stateOfMind)
        }
        
        return try PrevisitRecord(
            id: id,
            patientId: patientId,
            selectedDate: selectedDate,
            memo: memo,
            stateOfMind: stateOfMind,
            submittedAt: submittedAt
        )
    }
}

extension PrevisitRecordDTO {
    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case selectedDate = "selected_date"
        case memo
        case stateOfMind = "state_of_mind"
        case submittedAt = "submitted_at"
    }
}
