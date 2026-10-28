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
    var onIncompleteSignup: ((UUID, String) -> Void)?
    private var requestID: UUID?
    private var currentNonce: String?

    /// 버튼 → 입력 검사 → 인증 → 기본 사용자를 포함한 환자 조회 → 화면 성공의 순서입니다.
    /// Auth의 UUID만 받았다는 이유로 앱에 들어가지 않습니다. DB 프로필도 같은 사람이어야 합니다.
    func submit() async {
        guard !state.isSubmitting, !state.didSignIn else { return }
        state.errorMessage = nil
        state.emailError = AuthFormValidation.emailError(state.email)
        // 로그인은 기존 비밀번호 정책이 다를 수 있어 가입용 새 비밀번호 규칙을 강제하지 않습니다.
        state.passwordError = state.password.isEmpty ? "비밀번호를 입력해 주세요." : nil
        guard state.emailError == nil, state.passwordError == nil else { return }
        guard let auth = repositories.auth, let patients = repositories.patients else {
            state.errorMessage = "로그인 연결을 준비 중이에요. 환자 정보 연결 후 이용할 수 있어요."
            return
        }
        guard let token = session.begin() else {
            state.errorMessage = "이전 인증 요청을 마무리하고 있어요. 잠시 후 다시 시도해 주세요."
            return
        }
        requestID = token; state.isSubmitting = true
        let email = AuthFormValidation.email(state.email)
        let password = state.password
        // 성공 전에는 복원 권한을 주지 않습니다. 실패/취소된 SDK 세션이 남아도 홈으로 복원하지 않습니다.
        session.loginPreference.isEnabled = false
        defer { session.finish(token); state.isSubmitting = false }
        do {
            let id = try await auth.signIn(email: email, password: password)
            guard isCurrent(token) else { throw CancellationError() }
            let patient = try await patients.findById(id)
            guard isCurrent(token) else { throw CancellationError() }
            if patient == nil, let onIncompleteSignup {
                state.password = ""
                onIncompleteSignup(id, email)
                return
            }
            guard let patient, patient.user.id == id else {
                throw AuthFlowError("가입 정보가 아직 완성되지 않았어요. 가입 정보 확인이 필요해요.")
            }
            guard isCurrent(token) else { throw CancellationError() }
            session.loginPreference.isEnabled = true
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

    func prepareAppleSignIn() throws -> String {
        guard !state.isSubmitting, !state.didSignIn else {
            throw AuthFlowError("로그인이 진행 중이에요.")
        }
        let nonce = try NonceCreator.randomNonceString()
        currentNonce = nonce
        return NonceCreator.sha256(nonce)
    }

    func cancelAppleSignIn() {
        currentNonce = nil
    }

    func signInWithApple(idToken: String) async {
        guard !state.isSubmitting, !state.didSignIn else { return }
        
        state.errorMessage = nil
        
        guard let nonce = currentNonce else {
            state.errorMessage = "인증 요청 정보가 없어요. 다시 시도해 주세요."
            return
        }
        
        currentNonce = nil
        
        guard let auth = repositories.auth, let patients = repositories.patients else {
            state.errorMessage = "로그인 연결을 준비하지 못했어요."
            return
        }
        
        guard let token = session.begin() else {
            state.errorMessage = "이전 인증 요청을 마무리하고 있어요. 다시 시도해 주세요."
            return
        }
        
        requestID = token
        state.isSubmitting = true
        session.loginPreference.isEnabled = false
        
        defer {
            session.finish(token)
            state.isSubmitting = false
        }
        
        do {
            let id = try await auth.signInWithApple(idToken: idToken, nonce: nonce)
            guard isCurrent(token) else { throw CancellationError() }
            
            let patient = try await patients.findById(id)
            guard isCurrent(token) else { throw CancellationError() }

            guard let patient else {
                guard let onIncompleteSignup else {
                    throw AuthFlowError("가입 화면을 연결하지 못했어요.")
                }
                let email = try await auth.getCurrentUserEmail()
                guard isCurrent(token) else { throw CancellationError() }
                
                guard let email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AuthFlowError("가입에 필요한 이메일을 확인하지 못했어요.")
                }
                state.password = ""
                onIncompleteSignup(id, email)
                return
            }
            
            guard patient.user.id == id else {
                throw AuthFlowError("사용자 정보가 일치하지 않아요.")
            }
            
            session.loginPreference.isEnabled = true
            session.patient = patient
            state.password = ""
            state.didSignIn = true
        } catch {
            session.patient = nil
            do {
                if auth.isSignedIn() { try await auth.signOut() }
            } catch {
                state.errorMessage = "인증 상태를 정리하지 못했어요. 다시 로그인해 주세요."
            }
            if isCurrent(token), state.errorMessage == nil {
                state.errorMessage = (error as? AuthFlowError)?.message
                    ?? "Apple 로그인에 실패했어요. 다시 시도해 주세요."
            }
        }
    }

    /// 비밀번호 재설정 등으로 세션이 사라진 뒤 다시 로그인할 수 있게 이전 성공 표시를 해제합니다.
    func prepareForLogin() {
        guard session.patient == nil, !state.isSubmitting else { return }
        state.didSignIn = false
    }

    /// 요청 자체를 되돌리는 것은 아닙니다. 늦게 온 응답이 화면을 이동시키지 않도록 표시 권한만 폐기합니다.
    func cancel() { requestID = nil; currentNonce = nil }
    private func isCurrent(_ token: UUID) -> Bool { requestID == token && !Task.isCancelled }
}
