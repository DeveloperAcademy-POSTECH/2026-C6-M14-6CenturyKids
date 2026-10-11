nonisolated public enum BodySide: String, CaseIterable, Hashable, Sendable {
    case left = "left"
    case right = "right"
    case center = "center"
    case both = "both"
    case unspecified = "unspecified"

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
