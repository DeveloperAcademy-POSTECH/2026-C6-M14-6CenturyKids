//
//  ExerciseRepository.swift
//  ToDoc
//

import Foundation

protocol ExerciseRepository: Repository
where Entity == ExerciseGoal {
    func save(
        _ goal: ExerciseGoal,
        for patientId: UUID, /// 다이어그램의 userId -> patientId로 변경했다.
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
