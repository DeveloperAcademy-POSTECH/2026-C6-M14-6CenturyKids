/// 사용자 확인을 받은 Figma 암종 10개. DB 직렬화 값은 별도 계약으로 정합니다.
public enum CarcinomaType: CaseIterable, Sendable {
    case liver, thyroid, gallbladderAndBileDuct, colorectal, kidney
    case stomach, breast, prostate, pancreas, lung
}
