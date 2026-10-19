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

    /// 검증된 복구 세션 계약이 없으므로 메일 요청이나 비밀번호 변경을 시작하지 않습니다.
    func submit() async {
        guard !state.isSubmitting else { return }
        state.isRecoveryReady = false
        state.errorMessage = "비밀번호 재설정 연결을 준비 중이에요. 아직 메일 요청이나 비밀번호 변경은 이루어지지 않았어요."
    }

    /// URL이나 일반 로그인 세션만으로 비밀번호 변경을 허용하지 않습니다.
    func acceptRecoveryURL(_ url: URL) async -> Bool {
        state.isRecoveryReady = false
        state.errorMessage = "이 인증 링크를 처리할 준비가 되지 않았어요. 비밀번호 재설정 연결을 기다려 주세요."
        return false
    }

    func prepareEmailRequest() {
        guard !state.isSubmitting, !session.isBusy else { return }
        state.isRecoveryReady = false; state.needsSessionCleanup = false
        state.didSend = false; state.didUpdatePassword = false; state.errorMessage = nil
        state.passwordError = nil; state.emailError = nil
    }
    func cancel() {
        state.newPassword = ""; state.passwordConfirmation = ""
        state.isRecoveryReady = false; state.needsSessionCleanup = false
    }
}
