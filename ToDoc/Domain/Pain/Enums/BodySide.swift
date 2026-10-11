nonisolated public enum BodySide: CaseIterable, Hashable, Sendable {
    case left
    case right
    case center
    case both
    case unspecified

    public var displayName: String {
        switch self {
        case .left: "왼쪽"
        case .right: "오른쪽"
        case .center: "가운데"
        case .both: "양쪽"
        case .unspecified: "미지정"
        }
    }
}
