//
//  PainRepository.swift
//  ToDoc
//

#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation

protocol PainRepository: RecordRepository
where Entity == PainRecord {
    func findByPatientIdAndDate(
        patientId: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [PainRecord]
}
