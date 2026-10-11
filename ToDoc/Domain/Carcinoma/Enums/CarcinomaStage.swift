nonisolated public enum CarcinomaStage: CaseIterable, Sendable {
    case stage0, stage1, stage2, stage3, stage4

    public var displayName: String {
        switch self {
        case .stage0: "0기"
        case .stage1: "1기"
        case .stage2: "2기"
        case .stage3: "3기"
        case .stage4: "4기"
        }
    }
}
