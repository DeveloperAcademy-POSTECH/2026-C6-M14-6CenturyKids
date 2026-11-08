//
//  IntakeRepository.swift
//  ToDoc
//

import Foundation

protocol IntakeRepository: RecordRepository
where Entity == IntakeRecord {
    func findByPatientIdAndDate(
        patientId: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [IntakeRecord]
}
