import SwiftUI

struct SignupPasswordConfirmationView: View {
    @Bindable var model: SignupViewModel

    var body: some View {
        SignupStepScreen(model: model, title: "비밀번호를\n한 번 더 입력해 주세요") {
            AuthTextField(title: "비밀번호 확인", placeholder: "비밀번호를 한 번 더 입력해 주세요", text: $model.passwordConfirmation, isSecure: true, contentType: .newPassword)
                .onSubmit { model.next() }
            if !model.passwordConfirmation.isEmpty && model.password == model.passwordConfirmation { AuthMessage(text: "비밀번호가 일치해요", isError: false) }
        }
    }
}
