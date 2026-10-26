import CoreGraphics

/// 기존 컴포넌트의 크기·간격입니다. 최신 Figma 레이아웃으로 확정한 값은 아닙니다.
enum AppMetrics {
    /// 온보딩·로그인·회원가입을 포함한 공통 CTA 규격입니다.
    enum PillButton {
        static let height: CGFloat = 80
        static let cornerRadius: CGFloat = 40
        /// 본체 바깥에 추가되는 선입니다. Secondary에는 쓰지 않습니다.
        static let outerBorderWidth: CGFloat = 2
        static let iconSize: CGFloat = 12
    }

    enum BackButton {
        static let size: CGFloat = PillButton.height
        static let cornerRadius: CGFloat = PillButton.cornerRadius
    }

    enum Header {
        static let titleAreaMinimumHeight: CGFloat = 66
    }
}

enum AppSpacing {
    static let screenHorizontal: CGFloat = 24
    static let columnGap: CGFloat = 20

    enum PillButton {
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 16
    }

    enum BackButton {
        static let padding: CGFloat = 16
    }

    enum ButtonGroup {
        static let captionToButtons: CGFloat = 24
        static let horizontalGap: CGFloat = 20
        static let verticalGap: CGFloat = 20
        static let buttonsToSubAction: CGFloat = 32
    }

    enum Header {
        static let titleToDescription: CGFloat = 8
    }
}
