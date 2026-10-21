//
//  DoctorLookupDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/21/26.
//

import Foundation

struct DoctorLookupDTO: Decodable {
    let doctorId: UUID
    let doctorName: String
    let doctorCode: String
    let hospitalId: UUID
    let hospitalName: String
    let hospitalAddress: String
    
    func toDomain() -> DoctorConnectionInfo {
        return DoctorConnectionInfo(
            doctorId: doctorId,
            doctorName: doctorName,
            doctorCode: doctorCode,
            hospitalId: hospitalId,
            hospitalName: hospitalName,
            hospitalAddress: hospitalAddress
        )
    }
}

extension DoctorLookupDTO {
    enum CodingKeys: String, CodingKey {
        case doctorId = "doctor_id"
        case doctorName = "doctor_name"
        case doctorCode = "doctor_code"
        case hospitalId = "hospital_id"
        case hospitalName = "hospital_name"
        case hospitalAddress = "hospital_address"
    }
}
