import Observation

/// 인증 화면 안의 입력 모델과 이동만 보존합니다. 서비스 생성·세션 저장은 담당하지 않습니다.
@MainActor @Observable
final class AuthFlowModel {
    private(set) var screen: Screen
    let login: LoginViewModel
    private(set) var signup: SignupViewModel
    let passwordReset: PasswordResetViewModel
    @ObservationIgnored private let onSignedIn: () -> Void
    @ObservationIgnored private let onLogin: (() -> Void)?
    @ObservationIgnored private var reportedSignIn = false
    @ObservationIgnored private var signupReturnsToLogin: Bool

    init(entry: Screen = .login, login: LoginViewModel? = nil, signup: SignupViewModel? = nil,
         passwordReset: PasswordResetViewModel? = nil, onLogin: (() -> Void)? = nil,
         onSignedIn: @escaping () -> Void = {}) {
        self.signupReturnsToLogin = entry != .signup
        self.screen = entry
        self.login = login ?? LoginViewModel()
        self.signup = signup ?? SignupViewModel()
        self.passwordReset = passwordReset ?? PasswordResetViewModel()
        self.onLogin = onLogin
        self.onSignedIn = onSignedIn
    }

    /// 온보딩에서 직접 연 가입은 첫 단계에서 온보딩으로 돌아갑니다.
    func beginSignup() {
        cancel()
        showSignup()
        signupReturnsToLogin = false
    }

    func cancel() {
        login.cancel()
        signup.cancel()
        passwordReset.cancel()
    }

    func showSignup() {
        signupReturnsToLogin = true
        login.cancel()
        if signup.step == .completion { signup = signup.newDraft() }
        screen = .signup
    }

    func leaveSignup(onDismiss: () -> Void) {
        signup.cancel()
        if signupReturnsToLogin { showLogin() } else { onDismiss() }
    }

    func showLogin() {
        signup.cancel()
        passwordReset.cancel()
        screen = .login
    }

    func showPasswordReset() {
        login.cancel()
        passwordReset.prepareForRequest()
        if passwordReset.email.isEmpty { passwordReset.email = AuthFormValidation.trimmed(login.email) }
        screen = .passwordReset
    }

    func completeSignup() {
        guard screen == .signup, signup.step == .completion else { return }
        login.email = AuthFormValidation.trimmed(signup.email)
        login.password = ""
        login.cancel()
        showLogin()
        onLogin?()
    }

    func reportSignIn() {
        guard screen == .login, login.didSignIn, !reportedSignIn else { return }
        reportedSignIn = true
        onSignedIn()
    }
}
