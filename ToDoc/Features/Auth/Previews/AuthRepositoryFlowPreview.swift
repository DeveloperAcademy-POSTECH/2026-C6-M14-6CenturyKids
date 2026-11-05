#if DEBUG
import SwiftUI

/// 화면 작업용 미리보기입니다. AuthRepositories()의 모든 연결이 nil이므로 서버에 쓰지 않습니다.
/// 입력 예시와 미연결 오류를 확인하는 용도이며, 실제 로그인 성공을 흉내 내지 않습니다.
@MainActor private enum AuthRepositoryPreview {
    static func model(_ entry: AuthEntry) -> AuthFlowViewModel {
        let flow = AuthFlowViewModel(session: AuthSessionState())
        flow.open(entry)
        flow.login.state.email = "preview@example.com"
        flow.login.state.password = "Preview123!"
        flow.reset.state.email = "preview@example.com"
        return flow
    }
    static func terms() -> AuthFlowViewModel {
        let flow = model(.signup)
        flow.signup.state.step = .terms
        return flow
    }
    static func recoveryForm() -> PasswordResetScreenState {
        // 디자인 확인을 위한 표시 상태만 지정합니다. onSubmit이 nil이므로 실제 비밀번호를 바꿀 수 없습니다.
        let state = PasswordResetScreenState()
        state.isRecoveryReady = true
        return state
    }
}

#Preview("로그인 · 저장소 미연결") { AuthFlowView(viewModel: AuthRepositoryPreview.model(.login)) }
#Preview("가입 · 약관 본문 대기") { AuthFlowView(viewModel: AuthRepositoryPreview.terms()) }
#Preview("재설정 · 저장소 미연결") { AuthFlowView(viewModel: AuthRepositoryPreview.model(.passwordReset)) }
#Preview("새 비밀번호 · 화면 시안 대기") { PasswordResetView(state: AuthRepositoryPreview.recoveryForm()) }
#endif
