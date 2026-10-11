nonisolated public enum IntakeAmount: String, CaseIterable, Sendable {
    case veryFull = "veryFull"
    case moderate = "moderate"
    case smallAmount = "smallAmount"
    case barelyAte = "barelyAte"

    public var displayName: String {
        switch self {
        case .veryFull: "배부르게 먹었어요"
        case .moderate: "적당히 먹었어요"
        case .smallAmount: "조금 먹었어요"
        case .barelyAte: "거의 못 먹었어요"
        }
    }
}
