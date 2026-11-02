import SwiftUI

extension AppColors {
    enum Pain {
        static let locationChip = Color(red: 240 / 255, green: 240 / 255, blue: 238 / 255)
        /// Figma background/inverse-subtle: 부위 화면에서 고른 부위 칩
        static let selectedLocationChip = Color(red: 104 / 255, green: 100 / 255, blue: 104 / 255)
        /// Figma background/primary-subtle: 앞뒤 돌리기·시트 닫기 버튼
        static let primarySubtle = Color(red: 239 / 255, green: 251 / 255, blue: 212 / 255)
        static let summaryDivider = Color(red: 213 / 255, green: 213 / 255, blue: 210 / 255)
        static let gaugeHandle = Color(white: 176 / 255)
        static let gaugeZero = Color(white: 217 / 255)
        static let gaugeMaximum = Color(red: 1, green: 73 / 255, blue: 70 / 255)
        static let descriptor = Color(white: 28 / 255)

        // 디자인의 2점/8점 색을 보존하는 시각 보간이며 의료 분류가 아닙니다.
        private static let gaugeStops: [(Int, (Double, Double, Double))] = [
            (0, (197, 242, 118)), (2, (181, 235, 87)), (5, (255, 206, 70)),
            (8, (254, 150, 70)), (10, (255, 73, 70))
        ]
        static func gaugeScore(_ score: Int) -> Color {
            let score = min(10, max(0, score))
            let upper = gaugeStops.firstIndex { $0.0 >= score } ?? gaugeStops.count - 1
            let lower = max(0, upper - 1)
            let start = gaugeStops[lower], end = gaugeStops[upper]
            let ratio = end.0 == start.0 ? 0 : Double(score - start.0) / Double(end.0 - start.0)
            func component(_ from: Double, _ to: Double) -> Double { (from + (to - from) * ratio) / 255 }
            return Color(red: component(start.1.0, end.1.0), green: component(start.1.1, end.1.1),
                         blue: component(start.1.2, end.1.2))
        }
    }
}

extension AppSurfaceToken {
    static let painSummary = Self(fill: AppColors.Surface.control, cornerRadius: 32)
    static let painChange = Self(fill: AppColors.gray, cornerRadius: 20)
}
