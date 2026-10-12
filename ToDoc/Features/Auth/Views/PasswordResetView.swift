import SwiftUI

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @State var model: PasswordResetViewModel = PasswordResetViewModel()
    var onBack: (() -> Void)?
    @State private var request: Task<Void, Never>?

    var body: some View {
        @Bindable var model = model
        AuthFormScreen(title: model.didSend ? "이메일을\n확인해 주세요" : "비밀번호를\n잊으셨나요?",
                       onBack: finish) {
            if model.didSend {
                Text("등록된 이메일이라면 비밀번호 재설정 안내를 보내드려요.")
                    .appTextStyle(.label)
            } else {
                AuthTextField(title: "이메일", placeholder: "가입한 이메일을 입력해 주세요", text: $model.email,
                              keyboard: .emailAddress, contentType: .emailAddress, error: model.emailError)
                    .disabled(model.isSubmitting)
                if let error = model.errorMessage { AuthMessage(text: error) }
            }
        } footer: {
            Button {
                if model.didSend { finish() }
                else { request = Task { await model.submit() } }
            } label: {
                AuthSubmitLabel(title: model.didSend ? "로그인으로 돌아가기" : "재설정 안내 받기", isLoading: model.isSubmitting)
            }
            .buttonStyle(AppButtonStyle()).disabled(model.isSubmitting)
        }
        .onDisappear { request?.cancel(); model.cancel() }
    }
    private func finish() {
        if let onBack { onBack() } else { dismiss() }
    }
}

#Preview { PasswordResetView() }
