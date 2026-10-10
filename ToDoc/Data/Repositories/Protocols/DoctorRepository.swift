//
//  DoctorRepository.swift
//  ToDoc
//
//  Created by 허지우 on 10/10/26.
//

import Foundation

protocol DoctorRepository {
    func save(_ doctor: Doctor) async throws

    func findByName(
        _ name: String
    ) async throws -> [Doctor]

    func findByHospitalId(
        _ hospitalId: UUID
    ) async throws -> [Doctor]
    
    func findByUserId(_ userId: UUID) async throws -> Doctor?
}
