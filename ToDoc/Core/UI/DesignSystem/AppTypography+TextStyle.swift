import SwiftUI
import UIKit

private struct AppTypographyTextStyle: ViewModifier {
    let style: AppTypography.Semantic
    @ScaledMetric private var size: CGFloat

    init(style: AppTypography.Semantic) {
        self.style = style
        // 본문 크기 조절 곡선을 공통 기준으로 사용해 규격의 비율을 유지합니다.
        _size = ScaledMetric(wrappedValue: style.specification.size, relativeTo: .body)
    }

    func body(content: Content) -> some View {
        let specification = style.specification
        let scale = size / specification.size
        let font = resolvedFont(at: size)
        let lineHeight = specification.lineHeight * scale
        let extraLeading = max(0, lineHeight - font.lineHeight.rounded(.up))

        content
            .font(Font(font))
            .tracking(specification.letterSpacing * scale)
            .lineSpacing(extraLeading)
            .padding(.vertical, extraLeading / 2)
    }

    private func resolvedFont(at size: CGFloat) -> UIFont {
        _ = AppTypography.registerFont
        return UIFont(name: style.specification.weight.fontName, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: fallbackWeight)
    }

    private var fallbackWeight: UIFont.Weight {
        switch style.specification.weight {
        case .regular: .regular
        case .medium: .medium
        case .semiBold: .semibold
        case .bold: .bold
        }
    }
}

extension View {
    /// 최신 Figma 규격을 적용하며 글자 크기·행간·자간을 같은 비율로 확대합니다.
    func appTypography(_ style: AppTypography.Semantic) -> some View {
        modifier(AppTypographyTextStyle(style: style))
    }
}
