import SwiftUI

extension AppNavigation {
    struct PageTitle: View {
        enum Alignment {
            case center
            case leading
        }

        private let title: String
        private let alignment: Alignment
        private let overline: String?
        private let description: String?

        /// center는 overline, leading은 description을 선택적으로 표시합니다.
        init(
            _ title: String,
            alignment: Alignment = .leading,
            overline: String? = nil,
            description: String? = nil
        ) {
            self.title = title
            self.alignment = alignment
            self.overline = overline
            self.description = description
        }

        @ViewBuilder
        var body: some View {
            switch alignment {
            case .center:
                VStack(spacing: 4) {
                    if let overline {
                        Text(overline)
                            .appTypography(.label)
                            .foregroundStyle(AppColors.Semantic.Text.sub)
                    }
                    Text(title)
                        .appTypography(.title)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                        .accessibilityAddTraits(.isHeader)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            case .leading:
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .appTypography(.titleLarge)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                        .accessibilityAddTraits(.isHeader)
                    if let description {
                        Text(description)
                            .appTypography(.bodySmall)
                            .foregroundStyle(AppColors.Semantic.Text.sub)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
