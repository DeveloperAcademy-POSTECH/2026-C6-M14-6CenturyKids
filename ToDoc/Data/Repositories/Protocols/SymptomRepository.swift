//
//  SymptomRepository.swift
//  ToDoc
//

#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation

protocol SymptomRepository: RecordRepository
where Entity == SymptomRecord {
    func findByPatientIdAndDate(
        _ patientId: UUID,
        _ date: Date
    ) async throws -> SymptomRecord?
}
