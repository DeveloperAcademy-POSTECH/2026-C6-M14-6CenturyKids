//
//  PatientDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/13/26.
//

import Foundation

struct PatientDTO: Codable {
    let userId: UUID
    let doctorId: UUID?
    let carcinomaType: String?
    let carcinomaStage: String?
    
    init(patient: Patient) {
        userId = patient.user.id
        doctorId = patient.doctorId
        carcinomaType = patient.disease?.carcinoma.rawValue
        carcinomaStage = patient.disease?.stage.rawValue
    }
    
    func toDomain(user: User) -> Patient {
        let disease: CarcinomaDetail?
        
        switch (carcinomaType, carcinomaStage) {
        case (nil, nil):
            disease = nil
            
        case let (type?, stage?):
            guard let domainType = CarcinomaType(rawValue: carcinomaType) else {
                throw MappingError.invalidCarcinomaType(carcinomaType)
            }
            
            guard let domainStage = CarcinomaStage(rawValue: carcinomaStage) else {
                throw MappingError.invalidCarcinomaStage(carcinomaStage)
            }
            
            disease = CarcinomaDetail(carcinoma: domainType, stage: domainStage)
            
        default:
            throw MappingError.incompleteCarcinomaDetail
        }
        
        return Patient(user: user, doctorId: doctorId, disease: disease)
    }
}

extension PatientDTO {
    enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case doctorId = "doctor_id"
            case carcinomaType = "carcinoma_type"
            case carcinomaStage = "carcinoma_stage"
    }
}
