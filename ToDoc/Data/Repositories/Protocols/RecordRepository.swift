//
//  RecordRepository.swift
//  ToDoc
//

import Foundation

protocol RecordRepository: Repository {
    func save(
        _ entity: Entity,
        for patientId: UUID
    ) async throws

    func findByPatientId(
        _ patientId: UUID
    ) async throws -> [Entity]
}
