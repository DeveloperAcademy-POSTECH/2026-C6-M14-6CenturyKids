nonisolated public enum MealType: CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner

    public var displayName: String {
        switch self {
        case .breakfast: "아침"
        case .lunch: "점심"
        case .dinner: "저녁"
        }
    }
}
