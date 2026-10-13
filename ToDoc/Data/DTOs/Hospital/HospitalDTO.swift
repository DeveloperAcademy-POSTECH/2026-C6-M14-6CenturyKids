//
//  HospitalDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/13/26.
//

import Foundation

struct HospitalDTO: Codable {
    let id: UUID
    let name: String
    let code: String
    let address: String
    
    init(hospital: Hospital) {
        id = hospital.id
        name = hospital.name
        code = hospital.code
        address = hospital.address
    }
    
    func toDomain() throws -> Hospital {
        return try Hospital(id: id, name: name, code: code, address: address)
    }
}

extension HospitalDTO {
    enum CodingKeys: String, CodingKey {
            case id = "id"
            case name = "name"
            case code = "code"
            case address = "address"
    }
}
