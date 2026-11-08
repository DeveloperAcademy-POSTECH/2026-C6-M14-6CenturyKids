import SwiftUI

extension AppActions {
    /// Figma의 Text Button. 배경 없이 문구 자체를 동작으로 제공합니다.
    struct TextButton: View {
        private let title: String
        private let action: () -> Void

        init(_ title: String, action: @escaping () -> Void) {
            self.title = title
            self.action = action
        }

        var body: some View {
            SwiftUI.Button(action: action) {
                Text(title)
                    .appTypography(.labelLarge)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(AppColors.Semantic.Text.action)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        }
    }
}
