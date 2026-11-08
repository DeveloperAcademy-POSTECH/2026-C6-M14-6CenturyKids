import SwiftUI

extension AppCards {
    struct MenuCard: View {
        enum Style {
            case primary
            case `default`
        }

        private let title: String
        private let description: String?
        private let style: Style
        private let action: () -> Void

        init(
            _ title: String,
            description: String? = nil,
            style: Style = .default,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.description = description
            self.style = style
            self.action = action
        }

        var body: some View {
            SwiftUI.Button(action: action) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .appTypography(.labelLarge)
                            .foregroundStyle(titleColor)
                        if let description {
                            Text(description)
                                .appTypography(.bodySmall)
                                .foregroundStyle(secondaryColor)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    // 원본 space-between을 유지하고 큰 글자에서도 화살표와 겹치지 않습니다.
                    Spacer(minLength: 12)
                    Chevron(color: secondaryColor)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 24))
                .contentShape(RoundedRectangle(cornerRadius: 24))
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(AppActions.PressStyle())
        }

        private var titleColor: Color {
            switch style {
            case .primary: AppColors.Semantic.Text.onPrimary
            case .default: AppColors.Semantic.Text.default
            }
        }

        private var secondaryColor: Color {
            switch style {
            case .primary: AppColors.Semantic.Text.onPrimary
            case .default: AppColors.Semantic.Text.sub
            }
        }

        private var backgroundColor: Color {
            switch style {
            case .primary: AppColors.Semantic.Primary.default
            case .default: AppColors.Semantic.Background.surface
            }
        }
    }
}
