nonisolated public enum MealType: String, CaseIterable, Sendable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"

    public var displayName: String {
        switch self {
        case .breakfast: "아침"
        case .lunch: "점심"
        case .dinner: "저녁"
        }
    }
}
