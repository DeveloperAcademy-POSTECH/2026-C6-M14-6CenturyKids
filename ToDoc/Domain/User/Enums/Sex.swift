/// User.sex — 클래스 다이어그램의 두 값을 유지합니다.
nonisolated public enum Sex: String, CaseIterable, Sendable {
    case male = "male"
    case female = "female"

    public var displayName: String {
        switch self {
        case .male: "남성"
        case .female: "여성"
        }
    }
}
