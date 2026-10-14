//
//  SymptomRepository.swift
//  ToDoc
//

import Foundation

protocol SymptomRepository: RecordRepository
where Entity == SymptomRecord {
    func findByPatientIdAndDate(
        _ patientId: UUID,
        _ date: Date
    ) async throws -> SymptomRecord?
}
