//
//  PainRecordViewModel.swift
//  ToDoc
//
//  Created by 허지우 on 10/17/26.
//

#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation
import Observation

/// 통증 기록은 두 번에 나눠 저장합니다.
/// 먹기 전 통증을 먼저 저장하고, 1시간 뒤 같은 기록에 먹은 뒤 통증을 채웁니다.
@MainActor
@Observable
final class PainRecordViewModel {
    enum ConnectionState {
        case loading
        case ready
        case signedOut
        case patientUnavailable
        case failed
    }

    private enum PatientSource {
        case repositories(auth: any AuthRepository, patient: any PatientRepository)
        case knownPatient(UUID)
    }

    enum SaveError: Error {
        case patientUnavailable
        case missingScore
        case noPendingRecord
        case alreadySaving
    }

    /// 먹기 전 통증을 저장하고 이만큼 지나야 먹은 뒤 통증을 기록할 수 있습니다.
    static let afterDelay: TimeInterval = 60 * 60

    @ObservationIgnored private let patientSource: PatientSource
    private var patientId: UUID?
    private let painRepository: any PainRepository
    private var isLoading = false
    private(set) var connectionState: ConnectionState = .loading
    /// 가장 최근 기록이 먹은 뒤 통증을 기다리고 있으면 그 기록입니다.
    /// 새 기록을 저장하면 그 기록으로 바뀌어, 이전 기록은 먹기 전 점수만 남습니다.
    private(set) var pendingRecord: PainRecord?
    private(set) var selectedLocations: [BodyLocation] = []
    private(set) var painBefore: Int?
    private(set) var painAfter: Int?
    private(set) var isSaving = false

    /// 이 시각부터 이어서 기록할 수 있습니다.
    var afterAvailableDate: Date? {
        pendingRecord.map { $0.recordedDate.addingTimeInterval(Self.afterDelay) }
    }

    init(
        authRepository: any AuthRepository,
        patientRepository: any PatientRepository,
        painRepository: any PainRepository
    ) {
        patientSource = .repositories(auth: authRepository, patient: patientRepository)
        self.painRepository = painRepository
    }

    #if DEBUG
    init(patientId: UUID, painRepository: any PainRepository) {
        patientSource = .knownPatient(patientId)
        self.patientId = patientId
        self.painRepository = painRepository
    }
    #endif

    /// 화면에 들어올 때마다 불러 이어서 기록할 기록이 있는지 다시 확인합니다.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        connectionState = .loading
        defer { isLoading = false }

        do {
            guard let patientId = try await resolvePatientId() else {
                connectionState = .patientUnavailable
                return
            }
            let latest = try await painRepository.findLatestByPatientId(patientId)
            guard !Task.isCancelled else { return }

            pendingRecord = latest?.painAfter == nil ? latest : nil
            startNewRecord()
            connectionState = .ready
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            if case let .repositories(authRepository, _) = patientSource, !authRepository.isSignedIn() {
                connectionState = .signedOut
            } else {
                connectionState = .failed
            }
        }
    }

    func selectLocation(_ location: BodyLocation) {
        guard !selectedLocations.contains(location) else { return }
        selectedLocations.append(location)
    }

    func removeLocation(_ location: BodyLocation) {
        selectedLocations.removeAll { $0 == location }
    }

    func setBeforeScore(_ score: Int) {
        painBefore = score
    }

    func setAfterScore(_ score: Int) {
        painAfter = score
    }

    /// 입력을 비우고 먹기 전 점수는 10점, 먹은 뒤 점수는 0점에서 시작합니다.
    func startNewRecord() {
        selectedLocations = []
        painBefore = 10
        painAfter = 0
    }

    /// 먹기 전 통증을 저장합니다. 저장한 시각이 기록 시각입니다.
    func saveBeforeRecord(at date: Date = Date()) async throws -> PainRecord {
        guard !isSaving else { throw SaveError.alreadySaving }
        guard let patientId else { throw SaveError.patientUnavailable }
        guard let painBefore else { throw SaveError.missingScore }

        let record = try PainRecord(
            id: UUID(),
            patientId: patientId,
            recordedDate: date,
            location: selectedLocations,
            painBefore: painBefore,
            painAfter: nil
        )

        isSaving = true
        defer { isSaving = false }
        try await painRepository.save(entity: record)

        pendingRecord = record
        return record
    }

    /// 기다리던 기록에 먹은 뒤 통증을 채웁니다.
    func saveAfterRecord() async throws -> PainRecord {
        guard !isSaving else { throw SaveError.alreadySaving }
        guard let pending = pendingRecord else { throw SaveError.noPendingRecord }
        guard let painAfter else { throw SaveError.missingScore }

        let record = try PainRecord(
            id: pending.id,
            patientId: pending.patientId,
            recordedDate: pending.recordedDate,
            location: pending.location,
            painBefore: pending.painBefore,
            painAfter: painAfter
        )

        isSaving = true
        defer { isSaving = false }
        try await painRepository.savePainAfter(recordId: pending.id, painAfter: painAfter)

        pendingRecord = nil
        return record
    }

    private func resolvePatientId() async throws -> UUID? {
        if let patientId { return patientId }
        guard case let .repositories(authRepository, patientRepository) = patientSource else { return nil }

        let userId = try await authRepository.getCurrentUserId()
        try Task.checkCancellation()
        let patient = try await patientRepository.findById(userId)
        try Task.checkCancellation()

        patientId = patient?.user.id
        return patientId
    }
}
