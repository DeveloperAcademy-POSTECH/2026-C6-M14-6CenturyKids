import SwiftUI

extension AppTypography.Token {
    static let conversationWheelSelected = Self(size: 100, weight: .bold, tracking: -0.01, scales: false)
    static let conversationWheelAdjacent = Self(size: 40, weight: .bold, scales: false)
    static let incomingTitle = Self(size: 40, weight: .bold, relativeTo: .title)
    static let incomingSubtitle = Self(size: 16, weight: .medium, relativeTo: .caption)
    static let incomingControl = Self(size: 12, weight: .medium, relativeTo: .caption)
}

extension AppTypography {
    /// 기존 native 편집 행·임시 오류 UI의 시스템 글꼴을 보존합니다.
    enum NativeConversation {
        static let body = Font.body
        static let headline = Font.headline
        static let footnote = Font.footnote
    }
}
