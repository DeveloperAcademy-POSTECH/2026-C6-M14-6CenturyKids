//
//  PainLocationDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/16/26.
//

import Foundation

struct PainLocationDTO: Codable {
    let painRecordId: UUID
    let part: String
    let side: String
    let view: String
    
    init(painRecordId: UUID, bodyLocation: BodyLocation) {
        self.painRecordId = painRecordId
        part = bodyLocation.bodyPart.rawValue
        side = bodyLocation.bodySide.rawValue
        view = bodyLocation.bodyView.rawValue
    }
    
    func toDomain() throws -> BodyLocation {
        guard let domainPart = BodyPart(rawValue: part) else {
            throw MappingError.invalidBodyPart(part)
        }
        
        guard let domainSide = BodySide(rawValue: side) else {
            throw MappingError.invalidBodySide(side)
        }
        
        guard let domainView = BodyView(rawValue: view) else {
            throw MappingError.invalidBodyView(view)
        }
        
        return BodyLocation(bodyPart: domainPart, bodySide: domainSide, bodyView: domainView)
    }
}

extension PainLocationDTO {
    enum CodingKeys: String, CodingKey {
        case painRecordId = "pain_record_id"
        case part = "part"
        case side = "side"
        case view = "view"
    }
}
