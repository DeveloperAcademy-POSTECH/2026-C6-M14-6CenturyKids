/// 사용자 확인을 받은 Figma 암종 10개. 영문 case명을 문자열 값으로 사용합니다.
nonisolated public enum CarcinomaType: String, CaseIterable, Sendable {
    case liver = "liver"
    case thyroid = "thyroid"
    case gallbladderAndBileDuct = "gallbladderAndBileDuct"
    case colorectal = "colorectal"
    case kidney = "kidney"
    case stomach = "stomach"
    case breast = "breast"
    case prostate = "prostate"
    case pancreas = "pancreas"
    case lung = "lung"

    public var displayName: String {
        switch self {
        case .liver: "간암"
        case .thyroid: "갑상선암"
        case .gallbladderAndBileDuct: "담낭 및 담도암"
        case .colorectal: "대장암"
        case .kidney: "신장암"
        case .stomach: "위암"
        case .breast: "유방암"
        case .prostate: "전립선암"
        case .pancreas: "췌장암"
        case .lung: "폐암"
        }
    }
}
