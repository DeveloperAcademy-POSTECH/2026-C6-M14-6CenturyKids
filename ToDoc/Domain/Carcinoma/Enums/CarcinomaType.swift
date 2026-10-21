/// 기존 암종 15개와 사용자가 선택하는 '모름'. 영문 case명을 문자열 값으로 사용합니다.
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
    case larynx = "larynx"
    case thymus = "thymus"
    case esophagus = "esophagus"
    case smallIntestine = "smallIntestine"
    case anus = "anus"
    case unknown = "unknown"

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
        case .larynx: "후두암"
        case .thymus: "흉선암"
        case .esophagus: "식도암"
        case .smallIntestine: "소장암"
        case .anus: "항문암"
        case .unknown: "잘 모르겠어요"
        }
    }
}
