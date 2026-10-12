import SwiftUI

struct SignupEmailView: View {
    @Bindable var model: SignupViewModel

    var body: some View {
        SignupStepScreen(model: model, title: "이메일을\n입력해 주세요") {
            AuthTextField(title: "이메일", placeholder: "예: name@example.com", text: $model.email, keyboard: .emailAddress, contentType: .emailAddress)
                .onSubmit { model.next() }
        }
    }
}
