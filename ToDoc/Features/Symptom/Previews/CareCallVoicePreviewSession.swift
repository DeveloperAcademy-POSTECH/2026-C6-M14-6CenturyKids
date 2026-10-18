#if DEBUG
import Foundation

/// Development navigation keeps edited data separate from explicitly loading a Figma fixture.
struct CareCallVoicePreviewSession {
    var phase: CareCallVoicePhase
    var answer: String
    var items: [CareCallVoiceSummaryItem]
    var editingItemID: UUID?

    init(initialPhase: CareCallVoicePhase = .incoming) {
        phase = initialPhase
        answer = [.answer, .lastAnswer].contains(initialPhase) ? Self.sampleAnswer : ""
        items = [
            .init(id: UUID(), title: "설사", detailLabel: "횟수", detail: "5회", discomfort: 8),
            .init(id: UUID(), title: "피로", detailLabel: "지속 시간", detail: "오후 내내", discomfort: 6),
            .init(id: UUID(), title: "왼쪽 손", detailLabel: "지속 시간", detail: "3시간", discomfort: 7)
        ]
        if initialPhase == .editing {
            items[0].detailLabel = "지속 시간"
            items[0].detail = "하루에 5번 이상"
            items[2].title = "통증"
            items[2].location = "왼쪽 손"
            editingItemID = items[0].id
        }
    }

    mutating func navigate(to next: CareCallVoicePhase) {
        phase = next
        editingItemID = next == .editing ? items.first?.id : nil
    }

    mutating func switchMode() {
        navigate(to: phase == .emptyText ? .ready : .emptyText)
    }

    mutating func advance() {
        switch phase {
        case .incoming: navigate(to: .ready)
        case .ready: navigate(to: .listening)
        case .listening: navigate(to: .followUp)
        case .followUp:
            if answer.isEmpty { answer = Self.sampleAnswer }
            navigate(to: .answer)
        case .emptyText: navigate(to: .answer)
        case .answer: navigate(to: .lastAnswer)
        case .lastAnswer: navigate(to: .loading)
        default: break
        }
    }

    mutating func previous() {
        navigate(to: phase == .lastAnswer ? .answer : .followUp)
    }

    private static let sampleAnswer = "먹고 나서 저녁부터 아팠어요."
}
#endif
