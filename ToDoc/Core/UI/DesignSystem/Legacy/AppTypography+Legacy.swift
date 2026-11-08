import SwiftUI
import UIKit

/// 기존 heading/label/caption과 화면 modifier를 그대로 유지합니다.
extension AppTypography {
    enum Style {
        case heading, label, caption

        var size: CGFloat {
            switch self {
            case .heading: 20
            case .label: 16
            case .caption: 14
            }
        }

        var textStyle: Font.TextStyle {
            switch self {
            case .heading: .title3
            case .label: .body
            case .caption: .caption
            }
        }

        var fontName: String {
            switch self {
            case .heading: "PretendardVariable-Bold"
            case .label: "PretendardVariable-SemiBold"
            case .caption: "PretendardVariable-Medium"
            }
        }

        private var fallbackWeight: UIFont.Weight {
            switch self {
            case .heading: .bold
            case .label: .semibold
            case .caption: .medium
            }
        }

        func font(at size: CGFloat) -> UIFont {
            _ = AppTypography.registerFont
            guard let font = UIFont(name: fontName, size: size) else {
                #if DEBUG
                assertionFailure("등록한 Pretendard 폰트를 찾을 수 없습니다: \(fontName)")
                #endif
                // 배포 앱에서는 같은 크기·굵기의 시스템 폰트로 계속 표시합니다.
                return UIFont.systemFont(ofSize: size, weight: fallbackWeight)
            }
            return font
        }
    }
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
