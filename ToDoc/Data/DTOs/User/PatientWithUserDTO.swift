//
//  PatientWithUserDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/17/26.
//

import Foundation

struct PatientWithUserDTO: Decodable {
    let userId: UUID
    let doctorId: UUID?
    let carcinomaType: String?
    let carcinomaStage: String?
    let user: UserDTO
    
    func toDomain() throws -> Patient {
        let domainUser = try user.toDomain()
        
        let disease: CarcinomaDetail?
        
        switch (carcinomaType, carcinomaStage) {
        case (nil, nil):
            disease = nil
            
        case let (type?, stage?):
            guard let domainType = CarcinomaType(rawValue: type) else {
                throw MappingError.invalidCarcinomaType(type)
            }
            
            guard let domainStage = CarcinomaStage(rawValue: stage) else {
                throw MappingError.invalidCarcinomaStage(stage)
            }
            
            disease = CarcinomaDetail(carcinoma: domainType, stage: domainStage)
            
        default:
            throw MappingError.incompleteCarcinomaDetail
        }
        
        return Patient(user: domainUser, doctorId: doctorId, disease: disease)
    }
}

extension PatientWithUserDTO {
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case doctorId = "doctor_id"
        case carcinomaType = "carcinoma_type"
        case carcinomaStage = "carcinoma_stage"
        case user
    }
}
