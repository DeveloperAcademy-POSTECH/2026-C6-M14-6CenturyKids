import CoreText
import SwiftUI
import UIKit

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
