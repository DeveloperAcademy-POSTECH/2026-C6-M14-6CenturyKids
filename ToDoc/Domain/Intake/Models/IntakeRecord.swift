import Foundation

nonisolated public struct IntakeRecord: Sendable {
    public let id: UUID
    public let recordedDate: Date
    public private(set) var mealType: MealType
    public private(set) var intakeAmount: IntakeAmount

    public init(id: UUID, recordedDate: Date, mealType: MealType, intakeAmount: IntakeAmount) {
        self.id = id
        self.recordedDate = recordedDate
        self.mealType = mealType
        self.intakeAmount = intakeAmount
    }

    public mutating func updateMealType(_ mealType: MealType) {
        self.mealType = mealType
    }

    public mutating func updateIntakeAmount(_ intakeAmount: IntakeAmount) {
        self.intakeAmount = intakeAmount
    }
}
