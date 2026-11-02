import Foundation
import enum Auth.AuthError

/// 이메일 → 메일의 인증코드 확인 → 새 비밀번호 저장 → 로그아웃 순서로 비밀번호를 재설정합니다.
/// 인증코드를 확인해야만 복구 세션이 생기고, 그 세션으로만 비밀번호를 바꿉니다.
@MainActor final class PasswordResetViewModel {
    let state = PasswordResetScreenState()
    let repositories: AuthRepositories
    let session: AuthSessionState
    let configuration: AuthConfiguration
    init(repositories: AuthRepositories, session: AuthSessionState, configuration: AuthConfiguration) {
        self.repositories = repositories; self.session = session; self.configuration = configuration
        state.onSubmit = { [weak self] in Task { await self?.submit() } }
        state.onCancel = { [weak self] in self?.cancel() }
    }
    private var requestID: UUID?
    /// 인증코드를 보낸 이메일입니다. 화면 입력이 바뀌어도 이 이메일로 코드를 확인합니다.
    private var codeEmail = ""
    /// 코드 확인으로 생긴 복구 세션이 SDK에 남아 있는지 나타냅니다.
    private var hasRecoverySession = false

    func submit() async {
        guard !state.isSubmitting, !state.didUpdatePassword else { return }
        state.errorMessage = nil
        if state.needsSessionCleanup { await retrySessionCleanup() }
        else if state.isRecoveryReady { await updatePassword() }
        else if state.didSend { await verifyCode() }
        else { await sendCode() }
    }

    /// 등록되지 않은 이메일이어도 같은 안내를 보여 가입 여부를 드러내지 않습니다.
    private func sendCode() async {
        state.emailError = AuthFormValidation.emailError(state.email)
        guard state.emailError == nil else { return }
        guard let auth = repositories.auth else {
            state.errorMessage = "비밀번호 찾기 연결을 준비 중이에요."
            return
        }
        guard let token = begin() else { return }
        defer { finish(token) }
        let email = AuthFormValidation.email(state.email)
        do {
            try await auth.sendPasswordResetEmail(to: email, redirectTo: configuration.redirectURL)
            guard isCurrent(token) else { return }
            codeEmail = email; state.email = email
            state.code = ""; state.codeError = nil
            state.didSend = true
        } catch {
            guard isCurrent(token) else { return }
            state.errorMessage = (error as? AuthError)?.errorCode == .overEmailSendRateLimit
                ? "인증코드를 너무 자주 요청했어요. 잠시 후 다시 시도해 주세요."
                : "인증코드를 보내지 못했어요. 이메일과 네트워크를 확인해 주세요."
        }
    }

    private func verifyCode() async {
        let code = state.code.trimmingCharacters(in: .whitespacesAndNewlines)
        state.codeError = code.isEmpty ? "인증코드를 입력해 주세요." : nil
        guard state.codeError == nil, let auth = repositories.auth else { return }
        guard let token = begin() else { return }
        defer { finish(token) }
        // 복구 세션은 로그인이 아닙니다. 앱을 껐다 켜면 세션 복원이 이 세션을 지우도록 로그인 기록을 꺼 둡니다.
        session.loginPreference.isEnabled = false
        do {
            try await auth.verifyPasswordResetCode(email: codeEmail, code: code)
            hasRecoverySession = true
            // 화면을 떠난 뒤 늦게 성공하면 쓸 사람이 없는 복구 세션이므로 바로 지웁니다.
            guard isCurrent(token) else { _ = await endRecoverySession(auth); return }
            state.code = ""
            state.isRecoveryReady = true
        } catch {
            guard isCurrent(token) else { return }
            if (error as? AuthError)?.errorCode == .otpExpired {
                state.codeError = "인증코드가 맞지 않거나 만료되었어요. 다시 확인해 주세요."
            } else {
                state.errorMessage = "인증코드를 확인하지 못했어요. 네트워크를 확인한 뒤 다시 시도해 주세요."
            }
        }
    }

    private func updatePassword() async {
        state.passwordError = AuthFormValidation.passwordChangeError(state.newPassword)
        state.confirmationError = state.newPassword == state.passwordConfirmation ? nil : "새 비밀번호가 일치하지 않아요."
        guard state.passwordError == nil, state.confirmationError == nil else { return }
        guard hasRecoverySession, let auth = repositories.auth else {
            state.errorMessage = "인증이 끝났어요. 처음부터 다시 진행해 주세요."
            return
        }
        guard let token = begin() else { return }
        defer { finish(token) }
        do {
            try await auth.updatePassword(to: state.newPassword, nonce: nil)
        } catch {
            guard isCurrent(token) else { return }
            switch (error as? AuthError)?.errorCode {
            case .some(.samePassword): state.passwordError = "기존 비밀번호와 다른 비밀번호를 입력해 주세요."
            case .some(.weakPassword): state.passwordError = "비밀번호 조건에 맞게 다시 입력해 주세요."
            default: state.errorMessage = "비밀번호를 변경하지 못했어요. 다시 시도해 주세요."
            }
            return
        }
        state.newPassword = ""; state.passwordConfirmation = ""
        // 비밀번호는 이미 바뀌었으므로 화면을 떠났더라도 복구 세션은 지웁니다.
        let ended = await endRecoverySession(auth)
        guard isCurrent(token) else { return }
        state.needsSessionCleanup = !ended
        state.didUpdatePassword = ended
    }

    private func retrySessionCleanup() async {
        guard let auth = repositories.auth, let token = begin() else { return }
        defer { finish(token) }
        let ended = await endRecoverySession(auth)
        guard isCurrent(token) else { return }
        state.needsSessionCleanup = !ended
        state.didUpdatePassword = ended
        if !ended { state.errorMessage = "인증 상태를 정리하지 못했어요. 네트워크를 확인한 뒤 다시 시도해 주세요." }
    }

    /// 실패해도 로그인 기록이 꺼져 있어 다음 실행의 세션 복원이 다시 지웁니다.
    private func endRecoverySession(_ auth: any AuthRepository) async -> Bool {
        do {
            if auth.isSignedIn() { try await auth.signOut() }
            hasRecoverySession = false
            return true
        } catch { return false }
    }

    /// 메일 링크는 쓰지 않습니다. URL이나 일반 로그인 세션만으로 비밀번호 변경을 허용하지 않습니다.
    func acceptRecoveryURL(_ url: URL) async -> Bool {
        state.isRecoveryReady = false
        state.errorMessage = "이 링크로는 비밀번호를 바꿀 수 없어요. 비밀번호 찾기에서 메일의 인증코드를 입력해 주세요."
        return false
    }

    func prepareEmailRequest() {
        guard !state.isSubmitting, !session.isBusy else { return }
        state.isRecoveryReady = false; state.needsSessionCleanup = false
        state.didSend = false; state.didUpdatePassword = false; state.errorMessage = nil
        state.code = ""; state.codeError = nil
        state.passwordError = nil; state.confirmationError = nil; state.emailError = nil
    }
    /// 늦게 온 응답이 화면을 바꾸지 않게 하고, 쓰지 않은 복구 세션을 지웁니다.
    func cancel() {
        requestID = nil
        state.code = ""; state.newPassword = ""; state.passwordConfirmation = ""
        state.isRecoveryReady = false; state.needsSessionCleanup = false
        guard hasRecoverySession, let auth = repositories.auth else { return }
        // 진행 중인 요청이 있으면 그 요청이 끝나면서 지웁니다.
        Task {
            guard let token = session.begin() else { return }
            defer { session.finish(token) }
            _ = await endRecoverySession(auth)
        }
    }

    private func begin() -> UUID? {
        guard let token = session.begin() else {
            state.errorMessage = "이전 인증 요청을 마무리하고 있어요. 잠시 후 다시 시도해 주세요."
            return nil
        }
        requestID = token; state.isSubmitting = true
        return token
    }
    private func finish(_ token: UUID) {
        session.finish(token)
        state.isSubmitting = false
    }
    private func isCurrent(_ token: UUID) -> Bool { requestID == token && !Task.isCancelled }
}
