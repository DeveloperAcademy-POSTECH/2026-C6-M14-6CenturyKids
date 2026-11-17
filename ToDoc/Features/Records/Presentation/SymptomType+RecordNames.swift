#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// 하루 기록 화면에서만 쓰는 증상 이름과 순서 (Figma '하루 기록 · 통증 점수 — 개발 전달' 2번).
/// 다른 화면은 displayName을 그대로 씁니다.
extension SymptomType {
    /// 횟수가 같을 때 칸·카드 순서
    nonisolated static let recordOrder: [SymptomType] = [
        .nauseaVomiting, .diarrhea, .dehydrationNutrition, .rashItching, .numbness, .constipation, .oralPain, .other
    ]

    /// 그래프 칸 이름 (좁아서 짧게)
    nonisolated var recordChartName: String {
        switch self {
        case .nauseaVomiting: "메스꺼움"
        case .diarrhea: "설사"
        case .dehydrationNutrition: "식욕부진"
        case .rashItching: "피부발진"
        case .numbness: "손발저림"
        case .constipation: "변비"
        case .oralPain: "구내염"
        case .other: "기타"
        }
    }

    /// 세부 카드 이름
    nonisolated var recordCardName: String {
        switch self {
        case .nauseaVomiting: "오심·구토"
        case .dehydrationNutrition: "식욕부진"
        case .rashItching: "피부발진"
        default: displayName
        }
    }
}
