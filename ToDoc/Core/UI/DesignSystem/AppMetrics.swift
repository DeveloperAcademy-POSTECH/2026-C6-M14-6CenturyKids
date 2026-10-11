import CoreGraphics

/// 화면 폭이나 safe area는 시스템 레이아웃을 사용합니다.
enum AppMetrics {
    enum Header {
        static let titleAreaMinimumHeight: CGFloat = 66
    }

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
}
