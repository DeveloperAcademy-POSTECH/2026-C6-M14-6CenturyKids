import Foundation

/// Presentation-only questions. The retired discomfort rating is intentionally excluded; storage mapping is a later integration.
enum CareCallManualStep: String, CaseIterable, Identifiable {
    case symptoms, dailyLife, frequency, duration, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .symptoms: "증상 선택"
        case .dailyLife: "일상 생활"
        case .frequency: "횟수"
        case .duration: "지속 시간"
        case .other: "그 외의 불편"
        }
    }
    var question: String {
        switch self {
        case .symptoms: "어떤 증상이 있었나요?"
        case .dailyLife: "일상 생활에 어떤 지장이 있었나요?"
        case .frequency: "설사를 몇 번 하셨나요?"
        case .duration: "얼마나 지속 되었나요?"
        case .other: "그 외의 불편에는 어떤 증상이 있었나요?"
        }
    }
    var figmaNodeID: String {
        switch self {
        case .symptoms: "72:3342"
        case .dailyLife: "1:5402"
        case .frequency: "1:5457"
        case .duration: "1:5486"
        case .other: "72:3411"
        }
    }
    var allowsSkipping: Bool { self == .dailyLife || self == .other }
}

enum CareCallManualSymptom: String, CaseIterable, Identifiable {
    case fatigue, nausea, bowel, appetite, sleep, sensation, mouth, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fatigue: "피로 및 무기력"
        case .nausea: "메스꺼움 및 구토"
        case .bowel: "설사 및 변비"
        case .appetite: "식욕저하"
        case .sleep: "수면 문제"
        case .sensation: "손발 저림 및\n감각이상"
        case .mouth: "입 안 통증"
        case .other: "그 외의 불편"
        }
    }
}

/// Editable UI draft. A selected wheel's initial position is distinct from an entered answer.
struct CareCallManualDraft {
    var symptoms: Set<CareCallManualSymptom> = []
    var dailyLife = ""
    var other = ""
    /// 0...10 are exact counts; 11 is the display-only 10+ choice.
    var frequencyIndex = 10
    var hours = 1
    var minutes = 30
    var answeredSteps: Set<CareCallManualStep> = []

    func canContinue(_ step: CareCallManualStep) -> Bool {
        switch step {
        case .symptoms: !symptoms.isEmpty
        case .dailyLife: answeredSteps.contains(step) && !dailyLife.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .other: answeredSteps.contains(step) && !other.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: answeredSteps.contains(step)
        }
    }
}
