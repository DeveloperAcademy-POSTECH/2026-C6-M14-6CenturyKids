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
    private let patientId: UUID
    private let painRepository: any PainRepository
    private var preparedRecord: PainRecord?
    private var recordedDate: Date?
    private(set) var selectedLocations: [BodyLocation] = []
    private(set) var painBefore = 0
    private(set) var painAfter = 0
    private(set) var isSaving = false

    enum PreparationError: Error {
        case recordNotStarted
        case missingScores
    }

    enum SaveError: Error {
        case recordNotPrepared
        case alreadySaving
    }

    init(patientId: UUID, painRepository: any PainRepository) {
        self.patientId = patientId
        self.painRepository = painRepository
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
        try discardPreparedRecord()
        recordedDate = Date()
    }

    func prepareRecord(from input: PainFormInput) throws -> PainRecord {
        preparedRecord = nil

        guard let recordedDate else {
            throw PreparationError.recordNotStarted
        }

        guard let before = input.before, let after = input.after else {
            throw PreparationError.missingScores
        }

        let record = try PainRecord(
            id: UUID(),
            patientId: patientId,
            recordedDate: recordedDate, // -> view에서 따로 선어하는겥x
            location: input.locations,
            painBefore: before,
            painAfter: after
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

        try await painRepository.save(record, for: patientId)

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
    }
}
