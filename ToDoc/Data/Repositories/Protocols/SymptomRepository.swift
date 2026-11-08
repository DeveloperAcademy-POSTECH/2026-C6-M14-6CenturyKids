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
        patientId: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [SymptomRecord]
}
