//
//  PatientDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/13/26.
//

import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

struct PatientDTO: Codable {
    let userId: UUID
    let doctorId: UUID?
    let carcinomaType: String?
    let carcinomaStage: String?
    let carcinomaOtherName: String?
    
    init(patient: Patient) {
        userId = patient.user.id
        doctorId = patient.doctorId
        carcinomaType = patient.disease?.carcinoma.rawValue
        carcinomaStage = patient.disease?.stage.rawValue
        carcinomaOtherName = patient.disease?.otherName
    }
    
    func toDomain(user: User) throws -> Patient {
        let disease: CarcinomaDetail?
        
        switch (carcinomaType, carcinomaStage) {
        case (nil, nil):
            guard carcinomaOtherName == nil else { throw MappingError.incompleteCarcinomaDetail }
            disease = nil
            
        case let (type?, stage?):
            guard let domainType = CarcinomaType(rawValue: type) else {
                throw MappingError.invalidCarcinomaType(type)
            }
            
            guard let domainStage = CarcinomaStage(rawValue: stage) else {
                throw MappingError.invalidCarcinomaStage(stage)
            }
            
            disease = CarcinomaDetail(carcinoma: domainType, stage: domainStage,
                                     otherName: try validatedOtherName(for: domainType))
            
        default:
            throw MappingError.incompleteCarcinomaDetail
        }
        
        return Patient(user: user, doctorId: doctorId, disease: disease)
    }

    func encode(to encoder: Encoder) throws {
        let otherName = try validatedOtherName(for: carcinomaType.flatMap(CarcinomaType.init(rawValue:)))
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(doctorId, forKey: .doctorId)
        try container.encodeIfPresent(carcinomaType, forKey: .carcinomaType)
        try container.encodeIfPresent(carcinomaStage, forKey: .carcinomaStage)
        // nil도 명시적으로 전송해야 기타 → 일반 암종 변경 시 이전 이름이 DB에서 지워집니다.
        if let otherName {
            try container.encode(otherName, forKey: .carcinomaOtherName)
        } else {
            try container.encodeNil(forKey: .carcinomaOtherName)
        }
    }

    private func validatedOtherName(for type: CarcinomaType?) throws -> String? {
        guard type == .other else { return nil }
        let name = carcinomaOtherName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { throw MappingError.missingOtherCarcinomaName }
        return name
    }
}

extension PatientDTO {
    enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case doctorId = "doctor_id"
            case carcinomaType = "carcinoma_type"
            case carcinomaStage = "carcinoma_stage"
            case carcinomaOtherName = "carcinoma_other_name"
    }
}
