//
//  PatientRepository.swift
//  ToDoc
//
//  Created by 허지우 on 10/10/26.
//

import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

protocol PatientRepository : Repository where Entity == Patient {
    func save(patient: Patient) async throws

    func findByName(
        _ name: String
    ) async throws -> [Patient]

    func findByDoctorId(
        _ doctorId: UUID
    ) async throws -> [Patient]
}
