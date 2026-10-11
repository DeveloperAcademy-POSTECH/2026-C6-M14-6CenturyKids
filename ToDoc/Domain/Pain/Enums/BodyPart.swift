nonisolated public enum BodyPart: CaseIterable, Hashable, Sendable {
    case headFace
    case neck
    case shoulder
    case chest
    case abdomen
    case backLowerBack
    case pelvisButtocks
    case armHand
    case legFoot

    public var displayName: String {
        switch self {
        case .headFace: "머리·얼굴"
        case .neck: "목"
        case .shoulder: "어깨"
        case .chest: "가슴"
        case .abdomen: "배"
        case .backLowerBack: "등·허리"
        case .pelvisButtocks: "골반·엉덩이"
        case .armHand: "팔·손"
        case .legFoot: "다리·발"
        }
    }
}
