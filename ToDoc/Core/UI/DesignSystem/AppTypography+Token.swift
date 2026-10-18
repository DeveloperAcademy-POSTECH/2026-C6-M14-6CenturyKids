import SwiftUI
import UIKit

extension AppTypography {
    /// 기존 Heading/Label/Caption 외 하이파이 변형도 같은 폰트 등록·확대·fallback을 사용합니다.
    struct Token {
        let size: CGFloat
        var weight: Weight = .regular
        var relativeTo: Font.TextStyle = .body
        var tracking: CGFloat = 0 // 글자 크기에 대한 비율
        var scales = true // 그림 안 숫자처럼 기하에 맞춰야 하는 경우에만 false
    }

    enum Weight: String {
        case regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold"

        var fallback: UIFont.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            }
        }
    }

    static func font(for token: Token, size: CGFloat) -> UIFont {
        _ = registerFont
        return UIFont(name: "PretendardVariable-\(token.weight.rawValue)", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: token.weight.fallback)
    }
}

extension AppTypography.Token {
    static let body = Self(size: 16)
    static let bodySmall = Self(size: 15)
    static let bodyStrong = Self(size: 16, weight: .semibold)
    static let captionRegular = Self(size: 14)
    static let captionStrong = Self(size: 14, weight: .semibold)
    static let question = Self(size: 20, weight: .medium)
    static let sectionTitle = Self(size: 20, weight: .semibold)
    static let controlCaption = Self(size: 10)
    static let completionTitle = Self(size: 24, weight: .bold)
    static let value = Self(size: 18, weight: .semibold)
}

private struct AppTokenTextStyle: ViewModifier {
    let token: AppTypography.Token
    @ScaledMetric private var scaledSize: CGFloat

    init(token: AppTypography.Token) {
        self.token = token
        _scaledSize = ScaledMetric(wrappedValue: token.size, relativeTo: token.relativeTo)
    }

    func body(content: Content) -> some View {
        let size = token.scales ? scaledSize : token.size
        // 기본 토큰은 호출 화면의 자간을 덮지 않습니다.
        if token.tracking == 0 {
            content.font(Font(AppTypography.font(for: token, size: size)))
        } else {
            content.font(Font(AppTypography.font(for: token, size: size)))
                .tracking(size * token.tracking)
        }
    }
}

extension View {
    /// Auto 행간 변형. 기본 Heading의 130% 행간은 appTextStyle(.heading)이 계속 담당합니다.
    func appFont(_ token: AppTypography.Token) -> some View {
        modifier(AppTokenTextStyle(token: token))
    }
}
