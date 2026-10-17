import Foundation

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
    private var recoveryUserID: UUID?

    /// 메일 요청과 새 비밀번호 저장은 서로 다른 단계입니다. 메일 전송을 비밀번호 변경으로 표시하지 않습니다.
    func submit() async {
        guard !state.isSubmitting, !state.didUpdatePassword else { return }
        if state.isRecoveryReady { await updatePassword() }
        else { await sendEmail() }
    }

    private func sendEmail() async {
        state.errorMessage = nil
        state.emailError = AuthFormValidation.emailError(state.email)
        guard state.emailError == nil else { return }
        guard let auth = repositories.auth, let url = configuration.redirectURL,
              repositories.callbacks != nil else {
            state.errorMessage = "재설정 이메일의 앱 복귀 주소와 링크 처리를 준비 중이에요."; return
        }
        guard let token = session.begin() else { showBusy(); return }
        requestID = token; state.isSubmitting = true
        let email = AuthFormValidation.email(state.email)
        defer { state.isSubmitting = false; session.finish(token) }
        do {
            try await auth.sendPasswordResetEmail(to: email, redirectTo: url)
            if isCurrent(token) { state.didSend = true }
        } catch {
            if isCurrent(token) { state.errorMessage = "재설정 메일을 요청하지 못했어요. 잠시 후 다시 시도해 주세요." }
        }
    }

    /// 앱이 받은 URL은 신뢰하지 않습니다. 주소 일치 → Repository의 서버 검증 → 사용자 ID 일치를 모두 통과해야 합니다.
    /// 이 함수가 true를 반환한 경우에만 화면 조정자가 새 비밀번호 화면을 엽니다.
    func acceptRecoveryURL(_ url: URL) async -> Bool {
        guard !state.isSubmitting else { return false }
        state.errorMessage = nil
        guard configuration.accepts(url), let callback = repositories.callbacks, let auth = repositories.auth else {
            state.errorMessage = "이 인증 링크를 처리할 준비가 되지 않았어요. 앱 복귀 주소와 링크 연결을 확인해 주세요."; return false
        }
        guard let token = session.begin() else { showBusy(); return false }
        requestID = token; state.isSubmitting = true
        state.isRecoveryReady = false; recoveryUserID = nil; state.needsSessionCleanup = false
        state.didUpdatePassword = false; session.patient = nil
        session.loginPreference.isEnabled = false
        defer { state.isSubmitting = false; session.finish(token) }
        do {
            if auth.isSignedIn() { try await auth.signOut() }
            let id = try await callback.recoverPasswordSession(from: url)
            guard try await auth.getCurrentUserId() == id else { throw AuthFlowError("복구 계정이 일치하지 않아요.") }
            guard isCurrent(token) else { throw CancellationError() }
            recoveryUserID = id; state.isRecoveryReady = true
            state.newPassword = ""; state.passwordConfirmation = ""; state.passwordError = nil
            return true
        } catch {
            do { if auth.isSignedIn() { try await auth.signOut() } }
            catch { state.errorMessage = "인증 상태를 정리하지 못했어요. 다시 시도해 주세요." }
            if isCurrent(token), state.errorMessage == nil { state.errorMessage = "만료되었거나 사용할 수 없는 링크예요. 재설정 메일을 다시 요청해 주세요." }
            return false
        }
    }

    private func updatePassword() async {
        state.errorMessage = nil
        // 변경 성공 후 로그아웃만 실패했다면 비밀번호를 다시 바꾸지 않고 세션 정리만 재시도합니다.
        if !state.needsSessionCleanup {
            state.passwordError = AuthFormValidation.passwordError(state.newPassword)
            if state.passwordError == nil, state.newPassword != state.passwordConfirmation { state.passwordError = "비밀번호가 일치하지 않아요." }
            guard state.passwordError == nil else { return }
        }
        guard let auth = repositories.auth, let recoveryUserID else {
            state.errorMessage = "재설정 이메일의 링크를 먼저 확인해 주세요."; return
        }
        guard let token = session.begin() else { showBusy(); return }
        requestID = token; state.isSubmitting = true
        let password = state.newPassword
        defer { state.isSubmitting = false; session.finish(token) }
        do {
            if !state.needsSessionCleanup {
                guard try await auth.getCurrentUserId() == recoveryUserID else { throw AuthFlowError("복구 계정이 바뀌었어요. 이메일 링크를 다시 열어 주세요.") }
                guard isCurrent(token) else { throw CancellationError() }
                try await auth.updatePassword(to: password, nonce: nil)
                state.needsSessionCleanup = true
                state.newPassword = ""; state.passwordConfirmation = ""
            }
            try await auth.signOut()
            guard isCurrent(token) else { throw CancellationError() }
            self.recoveryUserID = nil; state.isRecoveryReady = false
            state.needsSessionCleanup = false; state.didUpdatePassword = true
        } catch {
            if isCurrent(token) {
                state.errorMessage = state.needsSessionCleanup
                    ? "비밀번호는 변경되었어요. 로그인으로 돌아가기 위한 인증 상태 정리를 다시 시도해 주세요."
                    : (error as? AuthFlowError)?.message ?? "비밀번호를 변경하지 못했어요. 링크와 네트워크를 확인해 주세요."
            } else {
                // 사용자가 뒤로 간 사이 요청이 끝났다면 세션을 정리하고 뒤늦게 화면을 이동시키지 않습니다.
                do { if auth.isSignedIn() { try await auth.signOut() } }
                catch { state.errorMessage = "인증 상태 정리를 다시 시도해 주세요." }
            }
        }
    }

    /// 재설정 화면을 새로 열 때 이전 전송 완료 안내를 지웁니다. 진행 중 요청은 그대로 마무리합니다.
    func prepareEmailRequest() {
        guard !state.isSubmitting, !session.isBusy else { return }
        guard !state.isRecoveryReady else { return }
        state.needsSessionCleanup = false
        state.didSend = false; state.didUpdatePassword = false; state.errorMessage = nil
        state.passwordError = nil; state.emailError = nil
    }
    func cancel() {
        requestID = nil; state.newPassword = ""; state.passwordConfirmation = ""
        let hadRecoverySession = recoveryUserID != nil
        recoveryUserID = nil; state.isRecoveryReady = false; state.needsSessionCleanup = false
        // 진행 중 작업은 자신의 catch/defer에서 정리합니다. 대기 중 복구 세션만 여기서 닫습니다.
        guard hadRecoverySession, !state.isSubmitting, let auth = repositories.auth, let token = session.begin() else { return }
        // 세션 잠금은 VM이 해제되더라도 반드시 풀려야 하므로 session을 별도로 보관합니다.
        let session = session
        Task { [weak self] in
            defer { session.finish(token) }
            do { try await auth.signOut() }
            catch { self?.state.errorMessage = "인증 상태를 정리하지 못했어요. 다시 로그인해 주세요." }
        }
    }
    private func isCurrent(_ token: UUID) -> Bool { requestID == token && !Task.isCancelled }
    private func showBusy() { state.errorMessage = "이전 인증 요청이 끝난 뒤 다시 시도해 주세요." }
}
