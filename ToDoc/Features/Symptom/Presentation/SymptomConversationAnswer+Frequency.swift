import Foundation

extension SymptomConversationAnswer {
    enum Frequency: Equatable, Sendable {
        case count(Int)
        /// Figma의 10+ 선택을 그대로 전달합니다. 11회 등으로 임의 변환하지 않습니다.
        case tenPlus
    }
}
