import SwiftUI

struct SignupCancerStageView: View {
    @Bindable var state: SignupScreenState
    var body: some View {
        SignupStepScreen(state: state, title: "병기를 알려주세요", buttonTitle: "다음",
                         subtitle: "가입한 후에도 내 정보에서 수정할 수 있어요", contentSpacing: 26) {
            Label("선택한 암 · \(state.cancerTitle)", systemImage: "checkmark.circle")
                .appTypography(.labelLarge).foregroundStyle(AppColors.Semantic.Text.default)
            LazyVStack(spacing: 6) {
                ForEach(CarcinomaStage.allCases.filter { $0 != .unknown }, id: \.self) { stage in
                    AuthChoice(title: stage.title, isSelected: state.stage == .known(stage)) { state.stage = .known(stage) }
                }
                AuthChoice(title: CarcinomaStage.unknown.displayName, isSelected: state.stage == .unknown) { state.stage = .unknown }
            }
        }
    }
}
