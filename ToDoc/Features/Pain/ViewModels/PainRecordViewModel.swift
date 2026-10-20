//
//  PainRecordViewModel.swift
//  ToDoc
//
//  Created by 허지우 on 10/17/26.
//

import Foundation
import Observation

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

    @ObservationIgnored private let patientSource: PatientSource
    private var patientId: UUID?
    private let painRepository: any PainRepository
    private var isLoadingPatient = false
    private var preparedRecord: PainRecord?
    private var recordedDate: Date?
    private(set) var connectionState: ConnectionState = .loading
    private(set) var selectedLocations: [BodyLocation] = []
    private(set) var painBefore: Int?
    private(set) var painAfter: Int?
    private(set) var isSaving = false

    enum PreparationError: Error {
        case patientUnavailable
        case recordNotStarted
        case missingScores
    }

    enum SaveError: Error {
        case recordNotPrepared
        case alreadySaving
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
        connectionState = .ready
    }
    #endif

    func loadPatient() async {
        guard patientId == nil, !isLoadingPatient else { return }
        guard case let .repositories(authRepository, patientRepository) = patientSource else { return }

        isLoadingPatient = true
        connectionState = .loading
        defer { isLoadingPatient = false }

        do {
            let userId = try await authRepository.getCurrentUserId()
            guard !Task.isCancelled else { return }

            let patient = try await patientRepository.findById(userId)
            guard !Task.isCancelled else { return }

            guard let patient else {
                connectionState = .patientUnavailable
                return
            }

            patientId = patient.user.id
            connectionState = .ready
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            connectionState = authRepository.isSignedIn() ? .failed : .signedOut
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

    func startRecord() throws {
        guard patientId != nil else {
            throw PreparationError.patientUnavailable
        }
        try discardPreparedRecord()
        recordedDate = Date()
    }

    func prepareRecord() throws -> PainRecord {
        preparedRecord = nil

        guard let recordedDate else {
            throw PreparationError.recordNotStarted
        }

        guard let patientId else {
            throw PreparationError.patientUnavailable
        }

        guard let painBefore, let painAfter else {
            throw PreparationError.missingScores
        }

        let record = try PainRecord(
            id: UUID(),
            patientId: patientId,
            recordedDate: recordedDate,
            location: selectedLocations,
            painBefore: painBefore,
            painAfter: painAfter
        )
        preparedRecord = record
        return record
    }

    func savePreparedRecord() async throws -> PainRecord {
        guard !isSaving else {
            throw SaveError.alreadySaving
        }

        guard let record = preparedRecord else {
            throw SaveError.recordNotPrepared
        }

        isSaving = true
        defer { isSaving = false }

        try await painRepository.save(entity: record)

        preparedRecord = nil
        recordedDate = nil
        return record
    }

    func discardPreparedRecord() throws {
        guard !isSaving else {
            throw SaveError.alreadySaving
        }

        preparedRecord = nil
        recordedDate = nil
        selectedLocations = []
        painBefore = nil
        painAfter = nil
    }
}
