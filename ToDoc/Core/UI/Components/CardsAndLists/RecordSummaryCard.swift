import SwiftUI

extension AppCards {
    /// Figma Record Summary Card. 기록 그래픽과 이동 동작은 화면이 전달합니다.
    struct RecordSummaryCard: View {
        private let title: String
        private let description: String
        private let image: Image
        private let action: () -> Void

        init(_ title: String, description: String, image: Image, action: @escaping () -> Void) {
            self.title = title
            self.description = description
            self.image = image
            self.action = action
        }

        var body: some View {
            SwiftUI.Button(action: action) {
                HStack(spacing: 20) {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .appTypography(.title)
                            .foregroundStyle(AppColors.Semantic.Text.default)
                        Text(description)
                            .appTypography(.bodySmall)
                            .foregroundStyle(AppColors.Semantic.Text.sub)
                    }
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Chevron()
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.Semantic.Background.surface,
                            in: RoundedRectangle(cornerRadius: 30))
                .contentShape(RoundedRectangle(cornerRadius: 30))
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(AppActions.PressStyle())
        }
    }
}
