import Foundation

/// 화면과 엔진 사이의 표현 계약입니다. 서비스/엔진이 이 타입을 직접 참조할 필요는 없습니다.
struct SymptomConversationQuestion: Identifiable, Sendable {
    let id: UUID
    let text: String
    let guidance: String?
    let progress: Double?
    let input: Input
    let isLastQuestion: Bool
    let allowsPrevious: Bool

    init(id: UUID, text: String, guidance: String?, progress: Double?, input: Input,
         isLastQuestion: Bool = false, allowsPrevious: Bool = false) {
        self.id = id
        self.text = text
        self.guidance = guidance
        self.progress = progress
        self.input = input
        self.isLastQuestion = isLastQuestion
        self.allowsPrevious = allowsPrevious
    }
}
