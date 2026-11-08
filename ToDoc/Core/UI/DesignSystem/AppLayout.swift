import CoreGraphics

/// Figma 03 Layout & Spacing의 최신 레이아웃 기준입니다.
enum AppLayout {
    /// Section 1의 iPhone용 2열 그리드. Figma 1x 기준값을 pt로 사용합니다.
    enum Phone {
        /// 콘텐츠 영역의 좌우 마진입니다. 시스템 Safe Area와 별도로 사용합니다.
        static let horizontalMargin: CGFloat = 24

        /// 두 열 사이의 간격(Gutter)입니다.
        static let columnSpacing: CGFloat = 20

        static let columnCount = 2
    }
}
