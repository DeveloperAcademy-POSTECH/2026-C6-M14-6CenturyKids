/// 사용자 확인을 받은 Figma 암종 10개. DB 직렬화 값은 별도 계약으로 정합니다.
nonisolated public enum CarcinomaType: CaseIterable, Sendable {
    case liver, thyroid, gallbladderAndBileDuct, colorectal, kidney
    case stomach, breast, prostate, pancreas, lung

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
