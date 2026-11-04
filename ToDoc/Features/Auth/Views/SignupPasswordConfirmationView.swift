import SwiftUI

struct SignupPasswordConfirmationView: View {
    @Bindable var state: SignupScreenState

    var body: some View {
        SignupStepScreen(state: state, title: "비밀번호를 한 번 더 입력해 주세요") {
            AuthTextField(title: "비밀번호 확인", placeholder: "", text: $state.passwordConfirmation,
                          showsLabel: false, isSecure: true, contentType: .newPassword)
                .onSubmit { state.onAction?(.next) }
            if state.passwordMatches { AuthMessage(text: "비밀번호가 일치해요", isError: false) }
        }
    }
}
