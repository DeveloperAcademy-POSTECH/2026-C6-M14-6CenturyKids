//
//  PatientRepository.swift
//  ToDoc
//
//  Created by 허지우 on 10/10/26.
//

import Foundation

protocol PatientRepository {
    func save(patient: Patient) async throws
    
    func findById(_ id: UUID) async throws -> Patient?

    func findByName(
        _ name: String
    ) async throws -> [Patient]

    func findByDoctorId(
        _ doctorId: UUID
    ) async throws -> [Patient]
}
