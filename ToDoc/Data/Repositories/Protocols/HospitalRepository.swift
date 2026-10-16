//
//  HospitalRepository.swift
//  ToDoc
//

import Foundation

protocol HospitalRepository: Repository
where Entity == Hospital {
    func save(
        hospital: Hospital
    ) async throws

    func findByName(
        _ name: String
    ) async throws -> [Hospital]

    func findByCode(
        _ code: String
    ) async throws -> Hospital?

    func findByDoctorId(
        _ doctorId: UUID
    ) async throws -> Hospital?

    func searchByAddress(
        _ keyword: String
    ) async throws -> [Hospital]
}
