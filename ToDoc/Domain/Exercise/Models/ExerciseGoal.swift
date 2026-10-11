import Foundation

nonisolated public struct ExerciseGoal: Sendable {
    public let id: UUID
    public let year: Int
    public let month: Int
    public let targetCount: Int
    public let exerciseRecords: [ExerciseRecord]

    public init(id: UUID, year: Int, month: Int, targetCount: Int, exerciseRecords: [ExerciseRecord]) throws {
        guard targetCount >= 0 else { throw TargetCountValidationError.belowMinimum }
        guard targetCount <= 100 else { throw TargetCountValidationError.aboveMaximum }
        self.id = id
        self.year = year
        self.month = month
        self.targetCount = targetCount
        self.exerciseRecords = exerciseRecords
    }

    public func findRecordByDate(date: Date) -> ExerciseRecord? {
        findRecordByDate(date: date, calendar: DomainDateRules.calendar)
    }

    func findRecordByDate(date: Date, calendar: Calendar) -> ExerciseRecord? {
        exerciseRecords.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
