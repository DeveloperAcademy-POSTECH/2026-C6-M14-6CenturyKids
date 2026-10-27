import SwiftUI

struct SignupNameView: View {
    @Bindable var state: SignupScreenState

    var body: some View {
        SignupStepScreen(state: state, title: "이름을 입력해 주세요") {
            AuthTextField(title: "이름", placeholder: "이름 입력", text: $state.name, contentType: .name)
                .onSubmit { state.onAction?(.next) }
        }
    }
}
