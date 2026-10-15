nonisolated public enum NotificationType: String, CaseIterable, Sendable {
    case exerciseGoalCreated = "exerciseGoalCreated"
    case commentArrived = "commentArrived"
    case intakeRecordReminder = "intakeRecordReminder"

    public var displayName: String {
        switch self {
        case .exerciseGoalCreated: "운동 목표 생성"
        case .commentArrived: "코멘트 도착"
        case .intakeRecordReminder: "식사 기록 알림"
        }
    }
}
