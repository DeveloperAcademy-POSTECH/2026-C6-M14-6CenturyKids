import SwiftUI

struct SignupNameView: View {
    @Bindable var state: SignupScreenState

    var body: some View {
        SignupStepScreen(state: state, title: "이름을 입력해 주세요") {
            AuthTextField(title: "이름", placeholder: "ex) 홍길동", text: $state.name,
                          showsLabel: false, contentType: .name)
                .appTextLimit($state.name, maximum: 30, shakes: true)
                .onSubmit { state.onAction?(.next) }
        }
    }
}
