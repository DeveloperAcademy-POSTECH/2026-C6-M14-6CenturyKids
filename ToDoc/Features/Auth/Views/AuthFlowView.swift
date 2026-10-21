import SwiftUI

/// View는 ViewModel이 가진 상태를 화면에 연결하고 사용자의 버튼 동작만 전달합니다.
@MainActor struct AuthFlowView: View {
    typealias Screen = AuthEntry
    @Environment(\.dismiss) private var dismiss
    @State private var model: AuthFlowViewModel
    @State private var confirmsSignupTest = false
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
                SignupFormView(state: model.signup.state, onBack: model.backFromSignup,
                               onLogin: model.loginAfterSignup, onRestart: model.restartSignupAfterConfirmation)
            case .passwordReset:
                PasswordResetView(state: model.reset.state, onBack: { model.open(.login) })
            }
        }
#if DEBUG
        .safeAreaInset(edge: .bottom) {
            if model.signup.configuration.isLocalSignupTest, model.screen == .signup {
                Text("실서버 가입 테스트 · 약관 동의 수집 제외")
                    .font(.caption).padding(8)
            } else if model.screen == .login || (model.screen == .signup && model.signup.state.step == .role) {
                Button("실서버 가입 테스트") { confirmsSignupTest = true }
                    .font(.caption).padding(12)
                    .disabled(model.session.isBusy || model.signup.state.isAccountLocked)
            }
        }
        .alert("테스트 계정을 만들까요?", isPresented: $confirmsSignupTest) {
            Button("취소", role: .cancel) {}
            Button("테스트 시작") { model.startLocalSignupTest() }
        } message: {
            Text("실제 서버에 계정과 사용자·환자 정보가 저장됩니다. 본인 소유의 새 테스트 이메일과 가상 프로필을 사용하세요. 승인 약관을 대신하지 않으며 약관 단계와 동의 저장은 제외합니다.")
        }
#endif
        .onChange(of: model.login.state.didSignIn) { _, signedIn in if signedIn { onSignedIn?() } }
    }
    private func close() {
        model.close()
        if let onClose { onClose() } else { dismiss() }
    }
}
