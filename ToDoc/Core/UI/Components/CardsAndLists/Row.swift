import SwiftUI

extension AppCards {
    /// Figma Row. action이 있으면 버튼이며, 없으면 읽기 전용 정보 행입니다.
    struct Row: View {
        private let title: String
        private let value: String?
        private let showsChevron: Bool
        private let action: (() -> Void)?

        init(_ title: String, value: String? = nil, showsChevron: Bool? = nil,
             action: (() -> Void)? = nil) {
            self.title = title
            self.value = value
            self.showsChevron = showsChevron ?? (action != nil)
            self.action = action
        }

        var body: some View {
            if let action {
                SwiftUI.Button(action: action) { content }
                    .buttonStyle(AppActions.PressStyle())
            } else {
                content
            }
        }

        private var content: some View {
            HStack(spacing: 12) {
                Text(title)
                    .appTypography(.body)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    if let value {
                        Text(value)
                            .appTypography(.body)
                            .foregroundStyle(AppColors.Semantic.Text.sub)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if showsChevron {
                        Chevron()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
    }
}
