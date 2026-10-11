nonisolated public enum SymptomType: CaseIterable, Sendable {
    case fatigueWeakness
    case nauseaVomiting
    case diarrheaConstipation
    case lossOfAppetite
    case sleepProblems
    case numbness
    case oralPain
    case other

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
