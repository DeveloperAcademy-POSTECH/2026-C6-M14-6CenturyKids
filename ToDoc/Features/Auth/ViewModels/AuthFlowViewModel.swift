import Foundation
import Observation

enum AuthRootRoute { case authentication, patient }

enum AuthEntry { case login, signup, passwordReset }

/// 각 ViewModel의 수명과 화면 이동을 묶는 조정자입니다. 인증/DB 요청은 각 ViewModel에서 수행합니다.
/// View가 다시 그려질 때 가입 진행 상태나 Repository 인스턴스가 새로 만들어지지 않게 합니다.
@MainActor @Observable final class AuthFlowViewModel {
    let session: AuthSessionState
    let login: LoginViewModel
    private(set) var signup: SignupViewModel
    let reset: PasswordResetViewModel
    let onboarding: OnboardingViewModel
    var screen: AuthEntry = .login
    var showsAuth = false
    var isHandlingLink = false
    var linkMessage: String?
    /// 진행 중 표시는 경로가 아닙니다. 화면을 교체하면 onDisappear가 진행 중인 복구 요청을 취소합니다.
    var rootRoute: AuthRootRoute { session.patient == nil ? .authentication : .patient }
    var showsProgress: Bool { isHandlingLink || onboarding.isRestoring }
    @ObservationIgnored private var startupTask: Task<Void, Never>?

    @ObservationIgnored private var signupReturnsToLogin = false

    init(repositories: AuthRepositories = .init(), configuration: AuthConfiguration = .init(),
         session: AuthSessionState) {
        self.session = session
        login = LoginViewModel(repositories: repositories, session: session)
        signup = SignupViewModel(repositories: repositories, session: session, configuration: configuration)
        reset = PasswordResetViewModel(repositories: repositories, session: session, configuration: configuration)
        onboarding = OnboardingViewModel(repositories: repositories, session: session)
        login.onIncompleteSignup = { [weak self] id, email in
            guard let self else { return }
            self.signup.cancel()
            let signup = SignupViewModel(repositories: repositories, session: session, configuration: configuration)
            signup.resumeAuthenticatedAccount(id: id, email: email)
            self.signup = signup
            self.signupReturnsToLogin = true
            self.screen = .signup; self.showsAuth = true
        }
    }
    func open(_ entry: AuthEntry) {
        if entry == .signup {
            signupReturnsToLogin = showsAuth && screen == .login
            // 완료한 계정의 UUID/저장 체크포인트가 다음 사람의 가입으로 넘어가지 않도록 새 VM을 만듭니다.
            // 미완료 가입은 재시도 정보를 가진 기존 VM을 그대로 유지합니다.
            if signup.state.step == .completion {
                signup = SignupViewModel(repositories: signup.repositories, session: session,
                                         configuration: signup.configuration)
            }
        }
        if entry == .login { login.prepareForLogin() }
        if entry == .passwordReset { reset.prepareEmailRequest() }
        screen = entry; showsAuth = true
    }
    func advanceOnboarding() {
        if onboarding.page < 4 { onboarding.selectPage(onboarding.page + 1) }
        else { open(.login) }
    }
    func backFromSignup() {
        if signupReturnsToLogin { open(.login) }
        else { close() }
    }
    func restartSignupAfterConfirmation() {
        guard signup.state.isAccountLocked, !signup.state.isWorking, !session.isBusy else { return }
        if signup.state.hasAuthenticatedAccount { loginAfterSignup(); return }
        signup.cancel()
        signup = SignupViewModel(repositories: signup.repositories, session: session,
                                 configuration: signup.configuration)
    }
    func close() {
        login.cancel(); signup.cancel(); reset.cancel()
        showsAuth = false
    }
    func loginAfterSignup() {
        if signup.state.step == .completion, let patient = signup.completedPatient {
            session.patient = patient
            return
        }
        signup.cancel()
        login.state.email = signup.state.email
        login.state.password = ""
        // 가입이 끝난 경우에만 화면 입력을 지웁니다. 중간 실패의 재시도 스냅샷은 SignupVM이 보관합니다.
        if signup.state.step == .completion {
            signup.state.password = ""; signup.state.passwordConfirmation = ""
        }
        open(.login)
    }
    func restoreSessionOnce() async {
        if let startupTask { await startupTask.value; return }
        let task = Task { await onboarding.restoreSession() }
        startupTask = task
        await task.value
    }
    func handleURL(_ url: URL) async {
        guard !isHandlingLink else { return }
        isHandlingLink = true
        defer { isHandlingLink = false }
        if await reset.acceptRecoveryURL(url) {
            screen = .passwordReset; showsAuth = true
        } else {
            linkMessage = reset.state.errorMessage
        }
    }
}
