//
//  DoctorDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/13/26.
//

import Foundation

struct DoctorDTO: Codable {
    let id: UUID
    let hospitalId: UUID
    let code: String
    
    init(doctor: Doctor) {
        id = doctor.user.id
        hospitalId = doctor.hospitalId
        code = doctor.code
    }
    
    func toDomain(user: User) -> Doctor {
        return Doctor(user: user, code: code, hospitalId: hospitalId)
    }
}

extension DoctorDTO {
    enum CodingKeys: String, CodingKey {
            case id = "user_id"
            case hospitalId = "hospital_id"
            case code = "code"
    }
}
