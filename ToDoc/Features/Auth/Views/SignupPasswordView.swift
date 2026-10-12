import SwiftUI

struct SignupPasswordView: View {
    @Bindable var model: SignupViewModel

    var body: some View {
        SignupStepScreen(model: model, title: "비밀번호를\n만들어 주세요") {
            AuthTextField(title: "비밀번호", placeholder: "비밀번호를 입력해 주세요", text: $model.password, isSecure: true, contentType: .newPassword)
                .onSubmit { model.next() }
            Text("영문·숫자를 포함해 8자 이상").appTextStyle(.caption).foregroundStyle(AppColors.Text.secondary)
        }
    }
}
