//
//  SymptomEntryParam.swift
//  ToDoc
//
//  Created by 앤디 on 10/19/26.
//

import Foundation

struct SymptomEntryParam: Encodable {
    let id: UUID
    let type: String
    let part: String?
    let side: String?
    let rawLocation: String?
    let presence: String
    let duration: Int?
    let count: Int?
    let detail: String?
    
    init(symptomEntry: SymptomEntry) {
        id = symptomEntry.id
        type = symptomEntry.symptomType.rawValue
        part = symptomEntry.bodyPart?.rawValue
        side = symptomEntry.bodySide?.rawValue
        rawLocation = symptomEntry.rawLocationText
        presence = symptomEntry.presence.rawValue
        duration = symptomEntry.durationMinutes
        count = symptomEntry.occurrenceCount
        detail = symptomEntry.detail
    }
}
