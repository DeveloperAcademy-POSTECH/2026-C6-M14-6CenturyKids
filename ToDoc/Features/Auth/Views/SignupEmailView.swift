import SwiftUI

struct SignupEmailView: View {
    @Bindable var state: SignupScreenState

    var body: some View {
        SignupStepScreen(state: state, title: "이메일을 입력해 주세요") {
            AuthTextField(title: "이메일", placeholder: "ex) example@email.com", text: $state.email,
                          showsLabel: false, keyboard: .emailAddress, contentType: .emailAddress)
                .onSubmit { state.onAction?(.next) }
        }
    }
}
