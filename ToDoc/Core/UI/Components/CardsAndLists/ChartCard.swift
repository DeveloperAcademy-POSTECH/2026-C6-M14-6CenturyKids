import SwiftUI

extension AppCards {
    /// 실제 차트 데이터와 접근성 설명은 주입하는 chart가 제공합니다.
    struct ChartCard<Chart: View>: View {
        private let title: String
        private let overline: String
        private let period: String
        private let chartHeight: CGFloat
        private let chart: Chart

        init(
            _ title: String,
            overline: String,
            period: String,
            chartHeight: CGFloat = 200,
            @ViewBuilder chart: () -> Chart
        ) {
            self.title = title
            self.overline = overline
            self.period = period
            self.chartHeight = chartHeight
            self.chart = chart()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(overline)
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                Text(title)
                    .appTypography(.title)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                Text(period)
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                // 원본 12pt spacer와 양쪽 stack gap 4pt로 기간 아래 총 20pt를 둡니다.
                Color.clear.frame(height: 12)
                    .accessibilityHidden(true)
                chart.frame(height: chartHeight)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
        }
    }
}
