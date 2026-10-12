import CoreText
import SwiftUI
import UIKit

/// Pretendard Variable의 실제 PostScript 이름을 사용합니다.
enum AppTypography {
    // 앱과 독립 Preview 모두 첫 사용 시 한 번 등록합니다.
    static let registerFont: Void = {
        guard let url = Bundle.main.url(forResource: "PretendardVariable", withExtension: "ttf") else {
            #if DEBUG
            assertionFailure("PretendardVariable.ttf 리소스가 없습니다.")
            #endif
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()
}

private struct AppTextStyle: ViewModifier {
    let style: AppTypography.Style
    @ScaledMetric private var size: CGFloat

    init(style: AppTypography.Style) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.textStyle)
    }

    func body(content: Content) -> some View {
        let font = style.font(at: size)
        // Heading은 130% 행간, 나머지는 폰트의 Auto 행간을 유지합니다.
        let extraLeading = style == .heading ? max(0, size * 1.3 - font.lineHeight.rounded(.up)) : 0
        content
            .font(Font(font))
            .tracking(style == .heading ? size * -0.01 : 0)
            .lineSpacing(extraLeading)
            .padding(.vertical, extraLeading / 2)
    }
}

extension View {
    func appTextStyle(_ style: AppTypography.Style) -> some View {
        modifier(AppTextStyle(style: style))
    }
}
