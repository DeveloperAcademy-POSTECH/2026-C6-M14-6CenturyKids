import Foundation

@MainActor final class PasswordResetViewModel {
    let state = PasswordResetScreenState()
    let repositories: AuthRepositories
    let session: AuthSessionState
    let configuration: AuthConfiguration
    private var requestID: UUID?
    private var ownsRecoverySession = false
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

    func matchesRecoveryURL(_ url: URL) -> Bool {
        guard let expected = configuration.redirectURL else { return false }
        return url.scheme?.lowercased() == expected.scheme?.lowercased()
            && url.host?.lowercased() == expected.host?.lowercased()
            && url.path == expected.path
            && url.port == expected.port
            && url.user == nil && url.password == nil
    }

    func acceptRecoveryURL(_ url: URL) async -> Bool {
        guard matchesRecoveryURL(url), !state.isSubmitting else { return false }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let codes = query.filter { $0.name == "code" }
        guard codes.count == 1, let code = codes.first?.value, !code.isEmpty,
              !query.contains(where: { ["error", "error_code", "error_description"].contains($0.name) }),
              url.fragment == nil else {
            state.errorMessage = "유효하지 않거나 만료된 복구 링크예요. 재설정 메일을 다시 요청해 주세요."
            return false
        }
        guard let auth = repositories.auth, let token = session.begin() else {
            state.errorMessage = "이전 인증 요청을 마무리하고 있어요. 잠시 후 링크를 다시 열어 주세요."
            return false
        }
        requestID = token
        state.isSubmitting = true
        state.errorMessage = nil
        defer {
            session.finish(token)
            if requestID == token { requestID = nil }
            state.isSubmitting = false
        }
        do {
            try await auth.acceptPasswordRecoveryURL(url)
            ownsRecoverySession = true
            session.loginPreference.isEnabled = false
            session.patient = nil
            guard requestID == token, !Task.isCancelled else {
                try await auth.signOut()
                ownsRecoverySession = false
                return false
            }
            state.newPassword = ""; state.passwordConfirmation = ""
            state.passwordError = nil; state.emailError = nil
            state.didSend = false; state.didUpdatePassword = false
            state.needsSessionCleanup = false
            state.isRecoveryReady = true
            return true
        } catch {
            guard requestID == token, !Task.isCancelled else { return false }
            state.errorMessage = "복구 링크를 확인하지 못했어요. 만료되었거나 이미 사용한 링크라면 메일을 다시 요청해 주세요."
            return false
        }
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
        guard ownsRecoverySession, let auth = repositories.auth, let token = session.begin() else { return }
        Task { @MainActor in
            defer { session.finish(token) }
            do {
                try await auth.signOut()
                ownsRecoverySession = false
            } catch {
                state.errorMessage = "복구 인증 상태를 정리하지 못했어요. 다시 시도해 주세요."
            }
        }
    }
}
