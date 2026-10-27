import SwiftUI

extension AppCards {
    /// Figma Mood Option. 선택 값과 변경 동작은 호출 화면이 관리합니다.
    struct MoodOption: View {
        private let title: String
        private let sub: String?
        private let avatar: AppFeedback.Avatar
        private let isSelected: Bool
        private let action: () -> Void

        init(
            _ title: String,
            sub: String? = nil,
            avatar: AppFeedback.Avatar,
            isSelected: Bool = false,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.sub = sub
            self.avatar = avatar
            self.isSelected = isSelected
            self.action = action
        }

        var body: some View {
            SwiftUI.Button(action: action) {
                HStack(spacing: 20) {
                    avatar.accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        if let sub {
                            Text(sub)
                                .appTypography(.bodySmall)
                                .foregroundStyle(AppColors.Semantic.Text.sub)
                        }
                        Text(title)
                            .appTypography(.body)
                            .foregroundStyle(AppColors.Semantic.Text.default)
                    }
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? AppColors.Semantic.Background.selected : AppColors.Semantic.Background.surface,
                            in: RoundedRectangle(cornerRadius: 30))
                .contentShape(RoundedRectangle(cornerRadius: 30))
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(AppActions.PressStyle())
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}
