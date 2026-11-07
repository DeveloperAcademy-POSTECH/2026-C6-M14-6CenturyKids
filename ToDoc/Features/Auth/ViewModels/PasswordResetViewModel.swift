import Foundation

@MainActor final class PasswordResetViewModel {
    let state = PasswordResetScreenState()
    let repositories: AuthRepositories
    let session: AuthSessionState
    let configuration: AuthConfiguration
    private var requestID: UUID?
    init(repositories: AuthRepositories, session: AuthSessionState, configuration: AuthConfiguration) {
        self.repositories = repositories; self.session = session; self.configuration = configuration
        state.onSubmit = { [weak self] in Task { await self?.submit() } }
        state.onCancel = { [weak self] in self?.cancel() }
    }

    func submit() async {
        guard !state.isSubmitting else { return }
        guard !state.isRecoveryReady else {
            state.errorMessage = "비밀번호 변경 연결을 준비 중이에요."
            return
        }
        await requestEmail()
    }

    /// URL이나 일반 로그인 세션만으로 비밀번호 변경을 허용하지 않습니다.
    func acceptRecoveryURL(_ url: URL) async -> Bool {
        state.isRecoveryReady = false
        state.errorMessage = "이 인증 링크를 처리할 준비가 되지 않았어요. 비밀번호 재설정 연결을 기다려 주세요."
        return false
    }

    func requestEmail() async {
        guard !state.isSubmitting, !state.isRecoveryReady else { return }

        state.errorMessage = nil
        state.didSend = false
        let email = AuthFormValidation.email(state.email)
        state.emailError = AuthFormValidation.emailError(email)
        guard state.emailError == nil else { return }
        guard let auth = repositories.auth, let redirectURL = configuration.redirectURL else {
            state.errorMessage = "비밀번호 재설정 연결을 준비하지 못했어요."
            return
        }
        guard let token = session.begin() else {
            state.errorMessage = "이전 인증 요청을 마무리하고 있어요. 다시 시도해 주세요."
            return
        }

        requestID = token
        state.isSubmitting = true
        defer {
            session.finish(token)
            if requestID == token { requestID = nil }
            state.isSubmitting = false
        }

        do {
            try await auth.sendPasswordResetEmail(to: email, redirectTo: redirectURL)
            guard requestID == token, !Task.isCancelled else { return }
            state.didSend = true
        } catch {
            guard requestID == token, !Task.isCancelled else { return }
            state.errorMessage = "재설정 안내 메일을 요청하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    func prepareEmailRequest() {
        guard !state.isSubmitting, !session.isBusy else { return }
        state.isRecoveryReady = false; state.needsSessionCleanup = false
        state.didSend = false; state.didUpdatePassword = false; state.errorMessage = nil
        state.passwordError = nil; state.emailError = nil
    }
    func cancel() {
        requestID = nil
        state.newPassword = ""; state.passwordConfirmation = ""
        state.isRecoveryReady = false; state.needsSessionCleanup = false
    }
}
