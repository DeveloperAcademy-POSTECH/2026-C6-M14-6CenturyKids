import SwiftUI

extension AppNavigation {
    struct Header: View {
        private let title: String
        private let description: String?

        init(_ title: String, description: String? = nil) {
            self.title = title
            self.description = description
        }

        var body: some View {
            VStack(spacing: 8) {
                Text(title)
                    .appTypography(.title)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .bottom)

                if let description {
                    Text(description)
                        .appTypography(.label)
                        .foregroundStyle(AppColors.Semantic.Text.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
    }
}
