import SwiftUI

/// View는 ViewModel이 가진 상태를 화면에 연결하고 사용자의 버튼 동작만 전달합니다.
@MainActor struct AuthFlowView: View {
    typealias Screen = AuthEntry
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AuthFlowViewModel
    var onClose: (() -> Void)?
    var onSignedIn: (() -> Void)?

    init(entry: Screen = .login, viewModel: AuthFlowViewModel,
         onClose: (() -> Void)? = nil, onSignedIn: (() -> Void)? = nil) {
        if !viewModel.showsAuth { viewModel.screen = entry }
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose; self.onSignedIn = onSignedIn
    }
    var body: some View {
        Group {
            switch viewModel.screen {
            case .login:
                LoginFormView(viewModel: viewModel.login, onSignup: { viewModel.open(.signup) },
                              onPasswordReset: { viewModel.open(.passwordReset) }, onBack: close)
            case .signup:
                SignupFormView(state: viewModel.signup.state, onBack: viewModel.backFromSignup,
                               onLogin: viewModel.loginAfterSignup, onRestart: viewModel.restartSignupAfterConfirmation)
            case .passwordReset:
                PasswordResetView(state: viewModel.reset.state, onBack: { viewModel.open(.login) })
            }
        }
        .onChange(of: viewModel.login.state.didSignIn) { _, signedIn in if signedIn { onSignedIn?() } }
    }
    private func close() {
        viewModel.close()
        if let onClose { onClose() } else { dismiss() }
    }
}
