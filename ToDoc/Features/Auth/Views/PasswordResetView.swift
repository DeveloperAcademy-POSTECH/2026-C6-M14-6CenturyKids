import SwiftUI

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @State var state: PasswordResetScreenState = PasswordResetScreenState()
    var onBack: (() -> Void)?

    /// 복구·완료 단계는 아직 별도 시안이 없어 기존 공통 입력/버튼으로만 표시합니다.
    /// 복구 가능 여부와 저장 성공 여부를 View가 추측하지 않고 VM의 결과를 그대로 표시합니다.
    var body: some View {
        @Bindable var state = state
        AuthFormScreen(title: title, onBack: finish, keyboardFooterBehavior: keyboardFooterBehavior) {
            if state.didUpdatePassword {
                Text("새 비밀번호로 다시 로그인해 주세요.").appTextStyle(.label)
            } else if state.isRecoveryReady {
                if state.needsSessionCleanup {
                    Text("비밀번호는 변경되었어요. 인증 상태를 정리하면 다시 로그인할 수 있어요.").appTextStyle(.label)
                } else {
                    AuthTextField(title: "새 비밀번호", placeholder: "영문과 숫자 8자 이상", text: $state.newPassword,
                                  isSecure: true, contentType: .newPassword, error: state.passwordError)
                        .disabled(state.isSubmitting)
                    AuthTextField(title: "새 비밀번호 확인", placeholder: "한 번 더 입력해 주세요", text: $state.passwordConfirmation,
                                  isSecure: true, contentType: .newPassword)
                        .disabled(state.isSubmitting)
                }
            } else if state.didSend {
                Text("등록된 이메일이라면 비밀번호 재설정 안내를 보내드려요.").appTextStyle(.label)
            } else {
                AuthTextField(title: "이메일", placeholder: "가입한 이메일을 입력해 주세요", text: $state.email,
                              keyboard: .emailAddress, contentType: .emailAddress, error: state.emailError)
                    .disabled(state.isSubmitting)
            }
            if let error = state.errorMessage { AuthMessage(text: error) }
        } footer: {
            Button {
                if canReturnToLogin { finish() } else { state.onSubmit?() }
            } label: { AuthSubmitLabel(title: buttonTitle, isLoading: state.isSubmitting) }
                .buttonStyle(AppButtonStyle()).disabled(state.isSubmitting || (!canReturnToLogin && state.onSubmit == nil))
        }
        .onDisappear { state.onCancel?() }
    }
    private var canReturnToLogin: Bool { state.didUpdatePassword || (state.didSend && !state.isRecoveryReady) }
    private var keyboardFooterBehavior: AuthKeyboardFooterBehavior {
        state.isRecoveryReady && !state.didUpdatePassword && !state.needsSessionCleanup ? .compact : .keepActions
    }
    private var title: String {
        if state.didUpdatePassword { return "비밀번호를\n변경했어요" }
        if state.isRecoveryReady { return "새 비밀번호를\n입력해 주세요" }
        return state.didSend ? "이메일을\n확인해 주세요" : "비밀번호를\n잊으셨나요?"
    }
    private var buttonTitle: String {
        if canReturnToLogin { return "로그인으로 돌아가기" }
        if state.needsSessionCleanup { return "인증 상태 정리 다시 시도" }
        return state.isRecoveryReady ? "비밀번호 변경하기" : "재설정 안내 받기"
    }
    private func finish() { if let onBack { onBack() } else { dismiss() } }
}

#Preview { PasswordResetView() }
