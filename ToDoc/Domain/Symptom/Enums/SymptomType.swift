nonisolated public enum SymptomType: String, CaseIterable, Sendable {
    case nauseaVomiting = "nauseaVomiting"
    case constipation = "constipation"
    case diarrhea = "diarrhea"
    case oralPain = "oralPain"
    case numbness = "numbness"
    case rashItching = "rashItching"
    case dehydrationNutrition = "dehydrationNutrition"
    case other = "other"

    public var displayName: String {
        switch self {
        case .nauseaVomiting: "오심·구토"
        case .constipation: "변비"
        case .diarrhea: "설사"
        case .oralPain: "구내염"
        case .numbness: "손발 저림"
        case .rashItching: "피부 발진·가려움"
        case .dehydrationNutrition: "탈수·영양"
        case .other: "기타"
        }
    }
}
