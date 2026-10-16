//
//  SymptomEntryDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/14/26.
//

import Foundation

struct SymptomEntryDTO: Codable {
    let id: UUID
    let symptomRecordId: UUID
    let type: String
    let part: String?
    let side: String?
    let rawLocation: String?
    let presence: String
    let duration: Int?
    let count: Int?
    let detail: String?
    
    init(symptomEntry: SymptomEntry, symptomRecordId: UUID) {
        id = symptomEntry.id
        self.symptomRecordId = symptomRecordId
        type = symptomEntry.symptomType.rawValue
        part = symptomEntry.bodyPart?.rawValue
        side = symptomEntry.bodySide?.rawValue
        rawLocation = symptomEntry.rawLocationText
        presence = symptomEntry.presence.rawValue
        duration = symptomEntry.durationMinutes
        count = symptomEntry.occurrenceCount
        detail = symptomEntry.detail
    }
    
    func toDomain() throws -> SymptomEntry {
        guard let domainType = SymptomType(rawValue: type) else {
            throw MappingError.invalidSymptomType(type)
        }
        
        let domainPart: BodyPart?
        if let part {
            guard let parsedPart = BodyPart(rawValue: part) else {
                throw MappingError.invalidBodyPart(part)
            }
            
            domainPart = parsedPart
        } else {
            domainPart = nil
        }
        
        let domainSide: BodySide?
        if let side {
            guard let parsedSide = BodySide(rawValue: side) else {
                throw MappingError.invalidBodySide(side)
            }
            
            domainSide = parsedSide
        } else {
            domainSide = nil
        }
        
        guard let domainPresence = SymptomPresence(rawValue: presence) else {
            throw MappingError.invalidSymptomPresence(presence)
        }
        
        return try SymptomEntry(id: id, symptomType: domainType, presence: domainPresence, bodyPart: domainPart, bodySide: domainSide, rawLocationText: rawLocation, durationMinutes: duration, occurrenceCount: count, detail: detail)
    }
}

extension SymptomEntryDTO {
    enum CodingKeys: String, CodingKey {
            case id = "id"
            case symptomRecordId = "symptom_record_id"
            case type = "type"
            case part = "part"
            case side = "side"
            case rawLocation = "raw_location"
            case presence = "presence"
            case duration = "duration"
            case count = "count"
            case detail = "detail"
    }
}
