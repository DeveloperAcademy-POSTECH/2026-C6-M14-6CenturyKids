import SwiftUI

extension AppNavigation {
    struct StepIndicator: View {
        enum Style {
            case count
            case dots
        }

        private let current: Int
        private let total: Int
        private let style: Style

        init(current: Int, total: Int, style: Style = .count) {
            self.total = max(0, total)
            self.current = total > 0 ? min(max(1, current), total) : 0
            self.style = style
        }

        var body: some View {
            indicator
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("진행 단계"))
                .accessibilityValue(Text("\(current) / \(total)"))
        }

        @ViewBuilder
        private var indicator: some View {
            switch style {
            case .count:
                Text("\(current) / \(total)")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
            case .dots:
                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { index in
                        let selected = index + 1 == current
                        RoundedRectangle(cornerRadius: 3)
                            .fill(selected ? AppColors.Semantic.Primary.default : AppColors.Semantic.Border.default)
                            .frame(width: selected ? 18 : 6, height: 6)
                    }
                }
            }
        }
    }
}
