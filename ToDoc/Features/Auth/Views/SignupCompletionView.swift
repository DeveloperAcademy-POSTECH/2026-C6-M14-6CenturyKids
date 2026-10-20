import SwiftUI

struct SignupCompletionView: View {
    let email: String
    let onLogin: () -> Void
    var body: some View {
        AuthFormScreen(title: "가입이 완료됐어요", progress: "C6") {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72)).foregroundStyle(AppColors.primary).accessibilityHidden(true)
                Text("가입한 계정으로 기록을 시작해 보세요.").appTextStyle(.label)
                VStack(spacing: 8) {
                    Text("환자").appTextStyle(.caption)
                    Text(email).appTextStyle(.label).textSelection(.enabled)
                }
                .padding(24).frame(maxWidth: .infinity)
                .background(AppColors.secondary, in: RoundedRectangle(cornerRadius: 20))
            }
            .frame(maxWidth: .infinity).padding(.top, 32)
        } footer: {
            Button("시작하기", action: onLogin).buttonStyle(AppButtonStyle())
        }
    }
}

#Preview { SignupCompletionView(email: "preview@example.com", onLogin: {}) }
