import SwiftUI

/// 기존 NavigationStack 안에서 사용하는 인증 화면 묶음입니다.
struct AuthFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var flow: AuthFlowModel
    var onClose: (() -> Void)? = nil

    var body: some View {
        Group {
            switch flow.screen {
            case .login:
                LoginFormView(model: flow.login, onSignup: flow.showSignup,
                              onPasswordReset: flow.showPasswordReset, onBack: onClose)
            case .signup:
                SignupFormView(model: flow.signup, onBack: {
                    flow.leaveSignup(onDismiss: close)
                }, onLogin: flow.completeSignup)
            case .passwordReset:
                PasswordResetView(model: flow.passwordReset, onBack: flow.showLogin)
            }
        }
        .onChange(of: flow.login.didSignIn, initial: true) { _, _ in flow.reportSignIn() }
        .onDisappear { flow.cancel() }
    }
    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}
