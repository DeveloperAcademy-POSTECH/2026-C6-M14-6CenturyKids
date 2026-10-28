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

    /// 가장 최근 기록 하나. 복용 후 점수가 비어 있으면 이어서 기록할 대상입니다.
    func findLatestByPatientId(_ patientId: UUID) async throws -> PainRecord?

    /// 복용 후 점수를 채웁니다. 1시간이 지나지 않았거나 더 새 기록이 있으면 서버가 거절합니다.
    func savePainAfter(recordId: UUID, painAfter: Int) async throws
}
