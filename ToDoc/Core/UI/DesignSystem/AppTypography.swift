import CoreText
import SwiftUI
import UIKit

/// 최신 Figma 타이포그래피 9개와 공용 폰트 등록입니다.
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

    /// Figma 02 Typography의 원본 명칭과 표 순서를 유지한 규격입니다.
    /// 기존 appTextStyle에는 자동 적용하지 않으며, 컴포넌트 재배치 때 사용합니다.
    enum Semantic: String, CaseIterable {
        case display = "Display"
        case headline = "Headline"
        case titleLarge = "Title-large"
        case title = "Title"
        case body = "Body"
        case bodySmall = "Body-small"
        case labelLarge = "Label-large"
        case label = "Label"
        case caption = "Caption"

        static let fontFamily = "Pretendard Variable"

        /// Figma 표의 기본 크기·절대 행간·자간 백분율입니다.
        var specification: Specification {
            switch self {
            case .display:
                Specification(size: 40, lineHeight: 48, weight: .bold,
                              letterSpacingPercent: -2.5, usage: "아이패드/표지 큰 제목")
            case .headline:
                Specification(size: 28, lineHeight: 36, weight: .bold,
                              letterSpacingPercent: -2.5, usage: "페이지 대표 제목")
            case .titleLarge:
                Specification(size: 24, lineHeight: 32, weight: .bold,
                              letterSpacingPercent: -2.3, usage: "화면 제목")
            case .title:
                Specification(size: 20, lineHeight: 28, weight: .bold,
                              letterSpacingPercent: -1.2, usage: "한 화면에 여러 섹션이 있을 때 섹션 제목")
            case .body:
                Specification(size: 16, lineHeight: 24, weight: .regular,
                              letterSpacingPercent: 0.5, usage: "본문")
            case .bodySmall:
                Specification(size: 14, lineHeight: 20, weight: .regular,
                              letterSpacingPercent: 1.5, usage: "보조 설명")
            case .labelLarge:
                Specification(size: 16, lineHeight: 24, weight: .semiBold,
                              letterSpacingPercent: 0.5, usage: "CTA 버튼 텍스트")
            case .label:
                Specification(size: 14, lineHeight: 20, weight: .medium,
                              letterSpacingPercent: 1.5, usage: "버튼, 탭 글자 등 누를 수 있는 용도")
            case .caption:
                Specification(size: 12, lineHeight: 16, weight: .regular,
                              letterSpacingPercent: 2.5, usage: "날짜, 주석")
            }
        }

        struct Specification {
            /// Figma px 기준값. iOS 화면 적용 시 크기 조절 정책과 함께 사용합니다.
            let size: CGFloat
            /// 글자 줄의 전체 높이이며 SwiftUI lineSpacing의 추가 간격과 다릅니다.
            let lineHeight: CGFloat
            let weight: Weight
            let letterSpacingPercent: CGFloat
            let usage: String

            var letterSpacing: CGFloat {
                size * letterSpacingPercent / 100
            }
        }

        enum Weight: Int {
            case regular = 400
            case medium = 500
            case semiBold = 600
            case bold = 700

            /// 앱에 포함된 PretendardVariable.ttf의 실제 PostScript 이름입니다.
            var fontName: String {
                switch self {
                case .regular: "PretendardVariable-Regular"
                case .medium: "PretendardVariable-Medium"
                case .semiBold: "PretendardVariable-SemiBold"
                case .bold: "PretendardVariable-Bold"
                }
            }
        }
    }
}
