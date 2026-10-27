import SwiftUI
import UIKit

/// 최신 Figma 타이포그래피(AppTypography.Semantic)를 크기·굵기·행간·자간 그대로 입힙니다.
/// 글자 크기는 Dynamic Type을 따라 커지고, 행간도 같은 비율로 늘어납니다.
private struct AppSemanticTextStyle: ViewModifier {
    let style: AppTypography.Semantic
    @ScaledMetric private var size: CGFloat

    init(style: AppTypography.Semantic) {
        _ = AppTypography.registerFont
        self.style = style
        _size = ScaledMetric(wrappedValue: style.specification.size, relativeTo: .body)
    }

    func body(content: Content) -> some View {
        let spec = style.specification
        let font = UIFont(name: spec.weight.fontName, size: size) ?? .systemFont(ofSize: size)
        let lineHeight = spec.lineHeight * size / spec.size
        content
            .font(Font(font))
            .tracking(size * spec.letterSpacingPercent / 100)
            .lineSpacing(max(0, lineHeight - font.lineHeight))
            .padding(.vertical, max(0, lineHeight - font.lineHeight) / 2)
    }
}

extension View {
    func appText(_ style: AppTypography.Semantic) -> some View {
        modifier(AppSemanticTextStyle(style: style))
    }
}
