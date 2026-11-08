import Foundation
#if canImport(Auth)
import enum Auth.AuthError
#endif

@MainActor final class PasswordResetViewModel {
    let state = PasswordResetScreenState()
    let repositories: AuthRepositories
    let session: AuthSessionState
    let configuration: AuthConfiguration
    private var requestID: UUID?
    private var ownsRecoverySession = false
    private var passwordWasUpdated = false
    private let now: () -> Date
    private var resendAvailableAt: Date?
    private var resendTask: Task<Void, Never>?
    init(repositories: AuthRepositories, session: AuthSessionState, configuration: AuthConfiguration,
         now: @escaping () -> Date = Date.init) {
        self.now = now
        self.repositories = repositories; self.session = session; self.configuration = configuration
        state.onSubmit = { [weak self] in Task { await self?.submit() } }
        state.onCancel = { [weak self] in self?.cancel() }
    }

    deinit { resendTask?.cancel() }

    func submit() async {
        guard !state.isSubmitting else { return }
        if state.isRecoveryReady {
            await updatePassword()
        } else {
            await requestEmail()
        }
    }

    func updatePassword() async {
        guard !state.isSubmitting, !state.didUpdatePassword else { return }
        state.errorMessage = nil
        state.passwordError = nil
        guard ownsRecoverySession, state.isRecoveryReady, let auth = repositories.auth else {
            state.errorMessage = "비밀번호 재설정 링크를 먼저 인증해 주세요."
            return
        }
        if !passwordWasUpdated {
            guard auth.isSignedIn() else {
                state.errorMessage = "복구 인증이 만료되었어요. 재설정 메일을 다시 요청해 주세요."
                return
            }
            state.passwordError = AuthFormValidation.passwordError(state.newPassword)
            guard state.passwordError == nil else { return }
            guard state.newPassword == state.passwordConfirmation else {
                state.passwordError = "새 비밀번호가 일치하지 않아요."
                return
            }
        }
        guard let token = session.begin() else {
            state.errorMessage = "이전 인증 요청을 마무리하고 있어요. 다시 시도해 주세요."
            return
        }
        requestID = token
        state.isSubmitting = true
        let newPassword = state.newPassword
        defer {
            session.finish(token)
            if requestID == token { requestID = nil }
            state.isSubmitting = false
        }
        do {
            if !passwordWasUpdated {
                try await auth.updatePassword(to: newPassword, nonce: nil)
                passwordWasUpdated = true
                state.newPassword = ""; state.passwordConfirmation = ""
                if requestID == token, !Task.isCancelled { state.needsSessionCleanup = true }
            }
            try await auth.signOut()
            ownsRecoverySession = false
            guard requestID == token, !Task.isCancelled else { return }
            state.needsSessionCleanup = false
            state.didUpdatePassword = true
        } catch {
            guard requestID == token, !Task.isCancelled else {
                if ownsRecoverySession {
                    do {
                        try await auth.signOut()
                        ownsRecoverySession = false
                    } catch { }
                }
                return
            }
            if passwordWasUpdated {
                state.errorMessage = "로그인 화면으로 돌아가지 못했어요. 다시 시도해 주세요."
                return
            }
            #if canImport(Auth)
            switch (error as? AuthError)?.errorCode {
            case .some(.samePassword):
                state.passwordError = "기존 비밀번호와 다른 비밀번호를 입력해 주세요."
            case .some(.weakPassword):
                state.passwordError = "더 강한 비밀번호를 입력해 주세요."
            default:
                state.errorMessage = "비밀번호를 변경하지 못했어요. 연결 상태를 확인한 뒤 다시 시도해 주세요."
            }
            #else
            state.errorMessage = "비밀번호를 변경하지 못했어요. 연결 상태를 확인한 뒤 다시 시도해 주세요."
            #endif
        }
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
            passwordWasUpdated = false
            state.isRecoveryReady = true
            resendTask?.cancel()
            return true
        } catch {
            guard requestID == token, !Task.isCancelled else { return false }
            state.errorMessage = "링크가 만료되었어요. 메일을 다시 요청해 주세요."
            return false
        }
    }

    func requestEmail() async {
        guard !state.isSubmitting, !state.isRecoveryReady else { return }
        refreshResendCooldown()
        guard state.resendCooldownSeconds == 0 else { return }

        state.errorMessage = nil
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
            resendAvailableAt = now().addingTimeInterval(60)
            refreshResendCooldown()
            guard requestID == token, !Task.isCancelled else { return }
            state.didSend = true
            startResendCooldown()
        } catch {
            guard requestID == token, !Task.isCancelled else { return }
            state.errorMessage = "재설정 안내 메일을 요청하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    func refreshResendCooldown() {
        state.resendCooldownSeconds = max(0, Int(ceil(resendAvailableAt?.timeIntervalSince(now()) ?? 0)))
    }

    private func startResendCooldown() {
        resendTask?.cancel()
        refreshResendCooldown()
        guard state.resendCooldownSeconds > 0 else { return }
        resendTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                guard let self else { return }
                self.refreshResendCooldown()
                if self.state.resendCooldownSeconds == 0 { return }
            }
        }
    }

    func prepareEmailRequest() {
        guard !state.isSubmitting, !session.isBusy else { return }
        state.isRecoveryReady = false; state.needsSessionCleanup = false
        state.didSend = false; state.didUpdatePassword = false; state.errorMessage = nil
        state.passwordError = nil; state.emailError = nil
        startResendCooldown()
    }
    func cancel() {
        resendTask?.cancel()
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
