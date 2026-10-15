import SwiftUI

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @State var state: PasswordResetScreenState = PasswordResetScreenState()
    var onBack: (() -> Void)?

    var body: some View {
        @Bindable var state = state
        AuthFormScreen(title: state.didSend ? "이메일을\n확인해 주세요" : "비밀번호를\n잊으셨나요?",
                       onBack: finish) {
            if state.didSend {
                Text("등록된 이메일이라면 비밀번호 재설정 안내를 보내드려요.")
                    .appTextStyle(.label)
            } else {
                if state.onSubmit == nil { AuthMessage(text: "재설정 기능 연결 전이에요.") }
                AuthTextField(title: "이메일", placeholder: "가입한 이메일을 입력해 주세요", text: $state.email,
                              keyboard: .emailAddress, contentType: .emailAddress, error: state.emailError)
                    .disabled(state.isSubmitting)
                if let error = state.errorMessage { AuthMessage(text: error) }
            }
        } footer: {
            Button {
                if state.didSend { finish() }
                else { state.onSubmit?() }
            } label: {
                AuthSubmitLabel(title: state.didSend ? "로그인으로 돌아가기" : "재설정 안내 받기", isLoading: state.isSubmitting)
            }
            .buttonStyle(AppButtonStyle()).disabled(state.isSubmitting || (!state.didSend && state.onSubmit == nil))
        }
        .onDisappear { state.onCancel?() }
    }
    private func finish() {
        if let onBack { onBack() } else { dismiss() }
    }
}

#Preview { PasswordResetView() }
