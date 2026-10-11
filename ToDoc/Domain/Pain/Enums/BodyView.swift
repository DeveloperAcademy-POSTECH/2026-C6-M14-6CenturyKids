nonisolated public enum BodyView: CaseIterable, Hashable, Sendable {
    case front
    case back
    case unspecified

    public var displayName: String {
        switch self {
        case .front: "앞면"
        case .back: "뒷면"
        case .unspecified: "미지정"
        }
    }
}
