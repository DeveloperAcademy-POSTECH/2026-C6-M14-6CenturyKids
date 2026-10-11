import SwiftUI

struct AppHeader: View {
    let title: String
    var description: String? = nil

    var body: some View {
        VStack(spacing: AppSpacing.Header.titleToDescription) {
            Text(title)
                .appTextStyle(.heading)
                .foregroundStyle(AppColors.Text.primary)
                .frame(minHeight: AppMetrics.Header.titleAreaMinimumHeight, alignment: .bottom)
                .accessibilityAddTraits(.isHeader)
            if let description {
                Text(description)
                    .appTextStyle(.label)
                    .foregroundStyle(AppColors.Text.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}
