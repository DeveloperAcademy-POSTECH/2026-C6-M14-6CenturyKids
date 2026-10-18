import Foundation

/// Latest Figma section 1:1657. These values describe UI only; no recording or persistence occurs here.
enum CareCallVoicePhase: String, CaseIterable, Identifiable {
    case incoming, ready, listening, followUp, emptyText, answer, lastAnswer, loading, completed, summary, editing

    var id: String { rawValue }
    var title: String {
        switch self {
        case .incoming: "전화 수신"
        case .ready: "대화 시작"
        case .listening: "음성 인식"
        case .followUp: "추가 질문"
        case .emptyText: "문자 입력 전"
        case .answer: "답변 확인"
        case .lastAnswer: "마지막 답변"
        case .loading: "기록 정리 중"
        case .completed: "기록 정리 완료"
        case .summary: "요약 확인"
        case .editing: "요약 수정"
        }
    }
    var figmaNodeID: String {
        switch self {
        case .incoming: "1:1658"
        case .ready: "1:1837"
        case .listening: "1:1690"
        case .followUp: "1:1718"
        case .emptyText: "1:1732"
        case .answer: "1:1758"
        case .lastAnswer: "1:1787"
        case .loading: "1:1816"
        case .completed: "1:1823"
        case .summary: "1:1870"
        case .editing: "1:1903"
        }
    }
}

/// Patient words remain verbatim and separate from explicitly selected numeric answers.
struct CareCallVoiceSummaryItem: Identifiable {
    let id: UUID
    var title: String
    var detailLabel: String
    var detail: String
    var location: String? = nil
    var frequency: String? = nil
    var duration: String? = nil
}
