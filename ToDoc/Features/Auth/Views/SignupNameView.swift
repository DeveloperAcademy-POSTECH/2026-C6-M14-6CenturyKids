import SwiftUI

struct SignupNameView: View {
    @Bindable var state: SignupScreenState

    var body: some View {
        SignupStepScreen(state: state, title: "이름을\n입력해 주세요") {
            AuthTextField(title: "이름", placeholder: "예: 김하늘", text: $state.name, contentType: .name)
                .onSubmit { state.onAction?(.next) }
        }
    }
}
