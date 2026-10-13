import SwiftUI

/// 화면 이동만 담당합니다. 하지의 새 ViewModel은 각 state와 콜백을 주입합니다.
struct AuthFlowView: View {
    enum Screen { case login, signup, passwordReset }
    @Environment(\.dismiss) private var dismiss
    @State private var screen: Screen
    @State private var login: LoginScreenState
    @State private var signup: SignupScreenState
    @State private var reset: PasswordResetScreenState
    var onClose: (() -> Void)?
    var onSignedIn: (() -> Void)?
    init(entry: Screen = .login, login: LoginScreenState = .init(), signup: SignupScreenState = .init(),
         reset: PasswordResetScreenState = .init(), onClose: (() -> Void)? = nil, onSignedIn: (() -> Void)? = nil) {
        _screen = State(initialValue: entry); _login = State(initialValue: login)
        _signup = State(initialValue: signup); _reset = State(initialValue: reset)
        self.onClose = onClose; self.onSignedIn = onSignedIn
    }
    var body: some View {
        Group {
            switch screen {
            case .login: LoginFormView(state: login, onSignup: { screen = .signup }, onPasswordReset: { screen = .passwordReset }, onBack: close)
            case .signup: SignupFormView(state: signup, onBack: { screen = .login }, onLogin: {
                login.email = signup.email; login.password = ""; signup.password = ""; signup.passwordConfirmation = ""; screen = .login
            })
            case .passwordReset: PasswordResetView(state: reset, onBack: { screen = .login })
            }
        }.onChange(of: login.didSignIn) { _, signedIn in if signedIn { onSignedIn?() } }
    }
    private func close() { if let onClose { onClose() } else { dismiss() } }
}
