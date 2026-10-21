import SwiftUI

extension AppTypography.Token {
    static let painCaption = Self(size: 14, weight: .medium)
    static let painBodySmall = Self(size: 15, weight: .medium)
    static let painGaugeEndpoint = Self(size: 16, weight: .semibold, scales: false)
    static let painGaugeBadge = Self(size: 22.4, weight: .semibold, scales: false)
}

extension AppTypography {
    /// 삭제 기호는 원본의 고정 크기 시스템 glyph를 유지합니다.
    static let painRemoveSymbol = Font.system(size: 18)
}
