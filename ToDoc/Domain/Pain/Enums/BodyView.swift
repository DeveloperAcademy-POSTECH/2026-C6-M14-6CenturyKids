nonisolated public enum BodyView: String, CaseIterable, Hashable, Sendable {
    case front = "front"
    case back = "back"
    case unspecified = "unspecified"

    public var displayName: String {
        switch self {
        case .front: "앞면"
        case .back: "뒷면"
        case .unspecified: "미지정"
        }
    }
}
