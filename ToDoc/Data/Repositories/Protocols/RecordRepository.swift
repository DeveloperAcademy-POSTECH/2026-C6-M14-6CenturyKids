//
//  RecordRepository.swift
//  ToDoc
//

import Foundation

protocol RecordRepository: Repository {
    func save(
        entity: Entity
    ) async throws

    func findByPatientId(
        _ patientId: UUID
    ) async throws -> [Entity]
}
