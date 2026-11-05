import SwiftUI

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @State var state: PasswordResetScreenState = PasswordResetScreenState()
    var onBack: (() -> Void)?

    /// 인증코드·복구·완료 단계는 아직 별도 시안이 없어 기존 공통 입력/버튼으로만 표시합니다.
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
                    AuthTextField(title: "새 비밀번호", placeholder: "영문, 숫자, 특수문자 조합 8~32자", text: $state.newPassword,
                                  isSecure: true, contentType: .newPassword, error: state.passwordError)
                        .disabled(state.isSubmitting)
                    AuthTextField(title: "새 비밀번호 확인", placeholder: "한 번 더 입력해 주세요", text: $state.passwordConfirmation,
                                  isSecure: true, contentType: .newPassword, error: state.confirmationError)
                        .disabled(state.isSubmitting)
                }
            } else if state.didSend {
                Text("등록된 이메일이라면 \(state.email)로 인증코드를 보내드렸어요.").appTextStyle(.label)
                AuthTextField(title: "인증코드", placeholder: "메일로 받은 인증코드", text: $state.code,
                              keyboard: .numberPad, contentType: .oneTimeCode, error: state.codeError)
                    .disabled(state.isSubmitting)
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
    private var canReturnToLogin: Bool { state.didUpdatePassword }
    private var keyboardFooterBehavior: AuthKeyboardFooterBehavior {
        state.isRecoveryReady && !state.didUpdatePassword && !state.needsSessionCleanup ? .compact : .keepActions
    }
    private var title: String {
        if state.didUpdatePassword { return "비밀번호를\n변경했어요" }
        if state.isRecoveryReady { return "새 비밀번호를\n입력해 주세요" }
        return state.didSend ? "인증코드를\n입력해 주세요" : "비밀번호를\n잊으셨나요?"
    }
    private var buttonTitle: String {
        if canReturnToLogin { return "로그인으로 돌아가기" }
        if state.needsSessionCleanup { return "인증 상태 정리 다시 시도" }
        if state.isRecoveryReady { return "비밀번호 변경하기" }
        return state.didSend ? "인증코드 확인하기" : "인증코드 받기"
    }
    private func finish() { if let onBack { onBack() } else { dismiss() } }
}

#Preview { PasswordResetView() }
