//
//  DoctorWithUserDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/17/26.
//

import Foundation

struct DoctorWithUserDTO: Decodable {
    let id: UUID
    let hospitalId: UUID
    let code: String
    let user: UserDTO
    
    func toDomain() throws -> Doctor {
        let user = try user.toDomain()
        
        return Doctor(user: user, code: code, hospitalId: hospitalId)
    }
}

extension DoctorWithUserDTO {
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case hospitalId = "hospital_id"
        case code
        case user
    }
}
