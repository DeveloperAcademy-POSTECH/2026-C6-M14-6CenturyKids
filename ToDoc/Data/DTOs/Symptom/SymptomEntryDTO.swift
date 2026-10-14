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
    let part: String
    let side: String
    let raw_location: String
    let presence: String
    let duration: Int
    let count: Int
    let detail: String
}
