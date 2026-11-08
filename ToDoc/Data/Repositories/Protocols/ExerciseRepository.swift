//
//  ExerciseRepository.swift
//  ToDoc
//

import Foundation

protocol ExerciseRepository: Repository
where Entity == ExerciseGoal {
    func save(
        goal: ExerciseGoal,
        for patientId: UUID,
        setBy doctorId: UUID
    ) async throws

    func findByPatientId(
        _ patientId: UUID
    ) async throws -> [ExerciseGoal]

    func findByPatientIdAndMonth(
        _ patientId: UUID,
        year: Int,
        month: Int
    ) async throws -> ExerciseGoal?
}
