import SwiftUI

extension AppNavigation {
    struct DateNavigator: View {
        private let date: String
        private let isPreviousEnabled: Bool
        private let isNextEnabled: Bool
        private let onPrevious: () -> Void
        private let onNext: () -> Void

        init(
            _ date: String,
            isPreviousEnabled: Bool = true,
            isNextEnabled: Bool = true,
            onPrevious: @escaping () -> Void,
            onNext: @escaping () -> Void
        ) {
            self.date = date
            self.isPreviousEnabled = isPreviousEnabled
            self.isNextEnabled = isNextEnabled
            self.onPrevious = onPrevious
            self.onNext = onNext
        }

        var body: some View {
            // 44pt 터치 영역 안의 24pt 아이콘과 날짜 사이에 시각 간격 20pt를 남깁니다.
            HStack(spacing: 10) {
                arrow("Prev", label: "이전 날짜", action: onPrevious)
                    .disabled(!isPreviousEnabled)

                Text(date)
                    .appTypography(.labelLarge)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                arrow("Next", label: "다음 날짜", action: onNext)
                    .disabled(!isNextEnabled)
            }
            .frame(minHeight: 44)
        }

        private func arrow(_ asset: String, label: String, action: @escaping () -> Void) -> some View {
            SwiftUI.Button(action: action) {
                Image("DesignSystem/Components/Navigation/\(asset)")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(label))
        }
    }
}
