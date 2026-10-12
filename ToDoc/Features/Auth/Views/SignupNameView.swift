import SwiftUI

struct SignupNameView: View {
    @Bindable var model: SignupViewModel

    var body: some View {
        SignupStepScreen(model: model, title: "이름을\n입력해 주세요") {
            AuthTextField(title: "이름", placeholder: "예: 김하늘", text: $model.name, contentType: .name)
                .onSubmit { model.next() }
        }
    }
}
