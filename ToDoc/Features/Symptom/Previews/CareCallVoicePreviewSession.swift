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
            .init(id: UUID(), title: "설사", detailLabel: "말씀하신 내용", detail: "먹고 나서 저녁부터 설사를 했어요.\n화장실에 자꾸 가게 돼서 밥 먹기가 두려워요.", frequency: "5번"),
            .init(id: UUID(), title: "피로", detailLabel: "말씀하신 내용", detail: "오후 내내 축 처졌어요. 잠깐 누워 있었어요."),
            .init(id: UUID(), title: "왼쪽 손", detailLabel: "말씀하신 내용", detail: "왼쪽 손이 찌릿찌릿했어요.\n컵을 들 때도 그랬어요.", duration: "3시간")
        ]
        if initialPhase == .editing {
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
