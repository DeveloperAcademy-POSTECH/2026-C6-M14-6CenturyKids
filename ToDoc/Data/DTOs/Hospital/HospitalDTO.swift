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
    let latitude: Double?
    let longitude: Double?
    
    init(hospital: Hospital) {
        id = hospital.id
        name = hospital.name
        code = hospital.code
        address = hospital.address
        latitude = hospital.latitude
        longitude = hospital.longitude
    }
    
    func toDomain() throws -> Hospital {
        return try Hospital(id: id, name: name, code: code, address: address, latitude: latitude, longitude: longitude)
    }
}

extension HospitalDTO {
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case code = "code"
        case address = "address"
        case latitude = "latitude"
        case longitude = "longitude"
    }
}
