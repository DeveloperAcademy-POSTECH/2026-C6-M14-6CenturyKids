import SwiftUI

extension AppFeedback {
    /// Figma의 Toast. 노출 시간과 접근성 알림은 호출 화면에서 관리합니다.
    struct Toast: View {
        private let message: String

        init(_ message: String) {
            self.message = message
        }

        var body: some View {
            Text(message)
                .appTypography(.bodySmall)
                .foregroundStyle(AppColors.Semantic.Text.inverse)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AppColors.Semantic.Background.inverse, in: Capsule())
        }
    }
}
