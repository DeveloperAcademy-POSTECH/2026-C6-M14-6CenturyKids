nonisolated public enum SymptomType: String, CaseIterable, Sendable {
    case fatigueWeakness = "fatigueWeakness"
    case nauseaVomiting = "nauseaVomiting"
    case diarrheaConstipation = "diarrheaConstipation"
    case lossOfAppetite = "lossOfAppetite"
    case sleepProblems = "sleepProblems"
    case numbness = "numbness"
    case oralPain = "oralPain"
    case other = "other"

    public var displayName: String {
        switch self {
        case .fatigueWeakness: "피로·무기력"
        case .nauseaVomiting: "메스꺼움·구토"
        case .diarrheaConstipation: "설사·변비"
        case .lossOfAppetite: "식욕 저하"
        case .sleepProblems: "수면 문제"
        case .numbness: "손발 저림·감각 이상"
        case .oralPain: "입안 통증"
        case .other: "그 밖의 불편 (기타)"
        }
    }
}
