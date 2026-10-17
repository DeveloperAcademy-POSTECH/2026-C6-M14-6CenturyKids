import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

@MainActor final class LoginViewModel {
    let state = LoginScreenState()
    let repositories: AuthRepositories
    let session: AuthSessionState
    init(repositories: AuthRepositories, session: AuthSessionState) {
        self.repositories = repositories; self.session = session
        state.onSubmit = { [weak self] in Task { await self?.submit() } }
        state.onCancel = { [weak self] in self?.cancel() }
    }
    private var requestID: UUID?

    /// 버튼 → 입력 검사 → 인증 → 사용자/환자 조회 → 화면 성공의 순서입니다.
    /// Auth의 UUID만 받았다는 이유로 앱에 들어가지 않습니다. DB 프로필도 같은 사람이어야 합니다.
    func submit() async {
        guard !state.isSubmitting, !state.didSignIn else { return }
        state.errorMessage = nil
        state.emailError = AuthFormValidation.emailError(state.email)
        // 로그인은 기존 비밀번호 정책이 다를 수 있어 가입용 새 비밀번호 규칙을 강제하지 않습니다.
        state.passwordError = state.password.isEmpty ? "비밀번호를 입력해 주세요." : nil
        guard state.emailError == nil, state.passwordError == nil else { return }
        guard let auth = repositories.auth, let users = repositories.users, let patients = repositories.patients else {
            state.errorMessage = "로그인 연결을 준비 중이에요. 사용자·환자 정보 연결 후 이용할 수 있어요."
            return
        }
        guard let token = session.begin() else {
            state.errorMessage = "이전 인증 요청을 마무리하고 있어요. 잠시 후 다시 시도해 주세요."
            return
        }
        requestID = token; state.isSubmitting = true
        let email = AuthFormValidation.email(state.email)
        let password = state.password
        defer { session.finish(token); state.isSubmitting = false }
        do {
            let id = try await auth.signIn(email: email, password: password)
            guard isCurrent(token) else { throw CancellationError() }
            guard let user = try await users.findById(id), user.id == id,
                  let patient = try await patients.findById(id), patient.user.id == id else {
                throw AuthFlowError("가입 정보가 아직 완성되지 않았어요. 회원가입 화면에서 이어서 진행해 주세요.")
            }
            guard isCurrent(token) else { throw CancellationError() }
            session.patient = patient
            state.password = ""
            state.didSignIn = true
        } catch {
            session.patient = nil
            // 실패/취소된 로그인이 SDK에만 남아 다음 실행에서 성공처럼 보이지 않도록 정리합니다.
            do { if auth.isSignedIn() { try await auth.signOut() } }
            catch { state.errorMessage = "인증 상태를 정리하지 못했어요. 연결을 확인한 뒤 다시 로그인해 주세요." }
            if isCurrent(token), state.errorMessage == nil {
                state.errorMessage = (error as? AuthFlowError)?.message ?? "로그인하지 못했어요. 이메일·비밀번호와 네트워크를 확인해 주세요."
            }
        }
    }

    /// 비밀번호 재설정 등으로 세션이 사라진 뒤 다시 로그인할 수 있게 이전 성공 표시를 해제합니다.
    func prepareForLogin() {
        guard session.patient == nil, !state.isSubmitting else { return }
        state.didSignIn = false
    }

    /// 요청 자체를 되돌리는 것은 아닙니다. 늦게 온 응답이 화면을 이동시키지 않도록 표시 권한만 폐기합니다.
    func cancel() { requestID = nil }
    private func isCurrent(_ token: UUID) -> Bool { requestID == token && !Task.isCancelled }
}
