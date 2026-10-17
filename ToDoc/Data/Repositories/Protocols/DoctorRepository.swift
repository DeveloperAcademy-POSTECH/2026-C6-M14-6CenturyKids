//
//  DoctorRepository.swift
//  ToDoc
//
//  Created by 허지우 on 10/10/26.
//

import Foundation

protocol DoctorRepository {
    func save(doctor: Doctor) async throws
    
    func findById(_ id: UUID) async throws -> Doctor?

    func findByName(
        _ name: String
    ) async throws -> [Doctor]

    func findByHospitalId(
        _ hospitalId: UUID
    ) async throws -> [Doctor]
    
    func findByCode(_ code: String) async throws -> Doctor?
}
