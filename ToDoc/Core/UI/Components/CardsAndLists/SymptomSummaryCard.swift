import SwiftUI

extension AppCards {
    /// Figma Symptom Summary Card. 진단·판정은 호출 화면이 전달하며 카드가 계산하지 않습니다.
    struct SymptomSummaryCard: View {
        private let title: String
        private let description: String
        private let status: AppFeedback.StatusTag?
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        init(_ title: String, description: String, status: AppFeedback.StatusTag? = nil) {
            self.title = title
            self.description = description
            self.status = status
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                headerLayout {
                    Text(title)
                        .appTypography(.labelLarge)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let status {
                        status
                    }
                }
                Text(description)
                    .appTypography(.bodySmall)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.Semantic.Background.default,
                        in: RoundedRectangle(cornerRadius: 30))
            .accessibilityElement(children: .combine)
        }

        private var headerLayout: AnyLayout {
            dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        }
    }
}
