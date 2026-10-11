import CoreGraphics

/// 환자 iPhone Design System에서 확인한 간격입니다. 단위는 pt입니다.
enum AppSpacing {
    static let screenHorizontal: CGFloat = 24
    static let columnGap: CGFloat = 20

    enum Header {
        static let titleToDescription: CGFloat = 8
    }

    enum ButtonGroup {
        static let captionToButtons: CGFloat = 24
        static let horizontalGap: CGFloat = 20
        static let verticalGap: CGFloat = 20
        static let buttonsToSubAction: CGFloat = 32
    }

    enum BackButton {
        static let padding: CGFloat = 16
    }

    enum PillButton {
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 16
    }
}
