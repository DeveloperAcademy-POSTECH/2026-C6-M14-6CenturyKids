import Foundation

nonisolated public struct ExerciseRecord: Sendable {
    public let id: UUID
    public let exerciseGoalId: UUID
    public let date: Date
    public private(set) var recordedAt: Date?
    public private(set) var isCompleted: Bool

    public init(id: UUID, exerciseGoalId: UUID, date: Date, recordedAt: Date?, isCompleted: Bool) {
        self.id = id
        self.exerciseGoalId = exerciseGoalId
        self.date = date
        self.recordedAt = recordedAt
        self.isCompleted = isCompleted
    }

    public mutating func toggleCompletion() {
        toggleCompletion(at: Date())
    }

    mutating func toggleCompletion(at timestamp: Date) {
        isCompleted.toggle()
        recordedAt = isCompleted ? timestamp : nil
    }
}
