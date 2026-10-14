/// 증상이 있었는지에 대한 환자의 답. 없음·모름도 답이라 저장한다 (기록 집계는 있음만 센다)
nonisolated public enum SymptomPresence: String, CaseIterable, Sendable {
    case present = "present"
    case absent = "absent"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .present: "있음"
        case .absent: "없음"
        case .unknown: "모름"
        }
    }
}
