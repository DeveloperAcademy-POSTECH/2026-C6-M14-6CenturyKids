//
//  IntakeRepository.swift
//  ToDoc
//

import Foundation

protocol IntakeRepository: RecordRepository
where Entity == IntakeRecord {
    func findByPatientIdAndDate(
        _ patientId: UUID,
        _ date: Date
    ) async throws -> [IntakeRecord]
}
