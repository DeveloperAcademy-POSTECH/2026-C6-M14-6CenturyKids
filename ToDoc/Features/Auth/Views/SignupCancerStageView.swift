import SwiftUI

struct SignupCancerStageView: View {
    @Bindable var state: SignupScreenState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        SignupStepScreen(state: state, title: "진단받을 때의\n병기를 알려주세요", buttonTitle: "다음") {
            Label("선택한 암 · \(state.cancerTitle)", systemImage: "checkmark.circle")
                .appTextStyle(.label)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                ForEach(CarcinomaStage.allCases, id: \.self) { stage in
                    AuthChoice(title: stage.title, isSelected: state.stage == .known(stage)) { state.stage = .known(stage) }
                }
                AuthChoice(title: "잘 모르겠어요", isSelected: state.stage == .unknown) { state.stage = .unknown }
            }
            AuthChoice(title: "다른 표현으로 들었어요", isSelected: state.stage == .other) { state.stage = .other }
            if state.stage == .other {
                AuthTextField(title: "병기 표현", placeholder: "들으신 표현을 입력해 주세요", text: $state.otherStage)
            }
            Text("가입 후에도 내 정보에서 수정할 수 있어요.").appTextStyle(.caption)
                .foregroundStyle(AppColors.Text.secondary)
        }
    }
}
