import SwiftUI

extension AppCards {
    /// Figma List Group. Row를 간격·구분선 없이 묶으며 제목은 선택 사항입니다.
    struct ListGroup<Rows: View>: View {
        private let title: String?
        private let rows: Rows

        init(_ title: String? = nil, @ViewBuilder rows: () -> Rows) {
            self.title = title
            self.rows = rows()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                if let title {
                    Text(title)
                        .appTypography(.bodySmall)
                        .foregroundStyle(AppColors.Semantic.Text.sub)
                        .accessibilityAddTraits(.isHeader)
                }
                VStack(spacing: 0) {
                    rows
                }
                .frame(maxWidth: .infinity)
                .background(AppColors.Semantic.Background.surface,
                            in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}
