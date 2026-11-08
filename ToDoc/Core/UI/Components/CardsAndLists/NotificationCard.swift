import SwiftUI

extension AppCards {
    struct NotificationCard: View {
        private let message: String
        private let source: String
        private let time: String
        private let avatar: AppFeedback.Avatar
        private let action: (() -> Void)?

        init(
            _ message: String,
            source: String,
            time: String,
            avatar: AppFeedback.Avatar,
            action: (() -> Void)? = nil
        ) {
            self.message = message
            self.source = source
            self.time = time
            self.avatar = avatar
            self.action = action
        }

        @ViewBuilder
        var body: some View {
            if let action {
                SwiftUI.Button(action: action) { content }
                    .buttonStyle(AppActions.PressStyle())
            } else {
                content
            }
        }

        private var content: some View {
            HStack(spacing: 16) {
                avatar.accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 0) {
                        Text(source)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Text(time)
                            .multilineTextAlignment(.trailing)
                    }
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .appTypography(.body)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
            .accessibilityElement(children: .combine)
        }
    }
}
