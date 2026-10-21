import SwiftUI

struct SignupCompletionView: View {
    let email: String
    let onLogin: () -> Void
    var body: some View {
        AuthFormScreen(title: "가입이 완료됐어요", progress: "C6") {
            VStack(spacing: AppSpacing.section) {
                // SF Symbol 크기이며 본문용 Pretendard 스타일을 적용하지 않습니다.
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72)).foregroundStyle(AppColors.primary).accessibilityHidden(true)
                Text("가입한 계정으로 기록을 시작해 보세요.").appTextStyle(.label)
                VStack(spacing: AppSpacing.compact) {
                    Text("환자").appTextStyle(.caption)
                    Text(email).appTextStyle(.label).textSelection(.enabled)
                }
                .padding(AppSpacing.section).frame(maxWidth: .infinity)
                .appSurface(.authInformation)
            }
            .frame(maxWidth: .infinity).padding(.top, AppSpacing.large)
        } footer: {
            Button("시작하기", action: onLogin).buttonStyle(AppButtonStyle())
        }
    }
}

#Preview { SignupCompletionView(email: "preview@example.com", onLogin: {}) }
