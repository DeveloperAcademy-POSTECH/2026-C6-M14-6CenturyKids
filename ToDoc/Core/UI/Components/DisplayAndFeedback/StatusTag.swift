import SwiftUI

extension AppFeedback {
    /// Figma의 Status Tag. 상태의 의미는 색상과 함께 문구로 전달합니다.
    struct StatusTag: View {
        private let title: String
        private let showsDot: Bool
        private let dotColor: Color

        init(
            _ title: String,
            showsDot: Bool = true,
            dotColor: Color = AppColors.Semantic.Border.error
        ) {
            self.title = title
            self.showsDot = showsDot
            self.dotColor = dotColor
        }

        var body: some View {
            HStack(spacing: 6) {
                if showsDot {
                    // Figma의 피드백 전용 색상은 미정이며 현재 border/error를 사용합니다.
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .appTypography(.bodySmall)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
