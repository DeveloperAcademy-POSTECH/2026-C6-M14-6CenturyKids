import SwiftUI

/// View는 ViewModel이 가진 상태를 화면에 연결하고 사용자의 버튼 동작만 전달합니다.
@MainActor struct AuthFlowView: View {
    typealias Screen = AuthEntry
    @Environment(\.dismiss) private var dismiss
    @State private var model: AuthFlowViewModel
    var onClose: (() -> Void)?
    var onSignedIn: (() -> Void)?

    init(entry: Screen = .login, model: AuthFlowViewModel? = nil,
         onClose: (() -> Void)? = nil, onSignedIn: (() -> Void)? = nil) {
        let model = model ?? AuthFlowViewModel()
        if !model.showsAuth { model.screen = entry }
        _model = State(initialValue: model)
        self.onClose = onClose; self.onSignedIn = onSignedIn
    }
    var body: some View {
        Group {
            switch model.screen {
            case .login:
                LoginFormView(state: model.login.state, onSignup: { model.open(.signup) },
                              onPasswordReset: { model.open(.passwordReset) }, onBack: close)
            case .signup:
                SignupFormView(state: model.signup.state, onBack: model.backFromSignup, onLogin: model.loginAfterSignup)
            case .passwordReset:
                PasswordResetView(state: model.reset.state, onBack: { model.open(.login) })
            }
        }
        .onChange(of: model.login.state.didSignIn) { _, signedIn in if signedIn { onSignedIn?() } }
    }
    private func close() {
        model.close()
        if let onClose { onClose() } else { dismiss() }
    }
}
