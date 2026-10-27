import SwiftUI

struct SignupEmailView: View {
    @Bindable var state: SignupScreenState

    var body: some View {
        SignupStepScreen(state: state, title: "이메일을 입력해 주세요") {
            AuthTextField(title: "이메일", placeholder: "이메일 입력", text: $state.email, keyboard: .emailAddress, contentType: .emailAddress)
                .onSubmit { state.onAction?(.next) }
        }
    }
}
