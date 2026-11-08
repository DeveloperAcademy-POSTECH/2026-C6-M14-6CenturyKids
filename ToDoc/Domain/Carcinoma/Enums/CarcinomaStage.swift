nonisolated public enum CarcinomaStage: String, CaseIterable, Sendable {
    case stage0 = "stage0"
    case stage1 = "stage1"
    case stage2 = "stage2"
    case stage3 = "stage3"
    case stage4 = "stage4"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .stage0: "0기"
        case .stage1: "1기"
        case .stage2: "2기"
        case .stage3: "3기"
        case .stage4: "4기"
        case .unknown: "잘 모르겠어요"
        }
    }
}
