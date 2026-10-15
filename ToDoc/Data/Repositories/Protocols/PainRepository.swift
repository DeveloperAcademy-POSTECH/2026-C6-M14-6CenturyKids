//
//  PainRepository.swift
//  ToDoc
//

import Foundation

protocol PainRepository: RecordRepository
where Entity == PainRecord {
    func findByPatientIdAndDate(
        _ patientId: UUID,
        _ date: Date
    ) async throws -> [PainRecord]
}
