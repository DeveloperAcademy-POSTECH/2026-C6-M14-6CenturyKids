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
    private(set) var isSaving = false

    enum PreparationError: Error {
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

    func prepareRecord(from input: PainFormInput, recordedDate: Date) throws -> PainRecord {
        preparedRecord = nil

        guard let before = input.before, let after = input.after else {
            throw PreparationError.missingScores
        }

        let record = try PainRecord(
            id: UUID(),
            patientId: patientId,
            recordedDate: recordedDate,
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
        return record
    }

    func discardPreparedRecord() throws {
        guard !isSaving else {
            throw SaveError.alreadySaving
        }

        preparedRecord = nil
    }
}
