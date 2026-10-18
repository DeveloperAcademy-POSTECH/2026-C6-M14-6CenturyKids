import SwiftUI

struct SignupCancerStageView: View {
    @Bindable var state: SignupScreenState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        SignupStepScreen(state: state, title: "진단받을 때의\n병기를 알려주세요", buttonTitle: "다음") {
            Label("선택한 암 · \(state.cancerTitle)", systemImage: "checkmark.circle")
                .appTextStyle(.label)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.item), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: AppSpacing.item) {
                ForEach(CarcinomaStage.allCases.filter { $0 != .unknown }, id: \.self) { stage in
                    AuthChoice(title: stage.title, isSelected: state.stage == .known(stage)) { state.stage = .known(stage) }
                }
                AuthChoice(title: CarcinomaStage.unknown.displayName, isSelected: state.stage?.value == .unknown) { state.stage = .unknown }
            }
            Text("가입 후에도 내 정보에서 수정할 수 있어요.").appTextStyle(.caption)
                .foregroundStyle(AppColors.Text.secondary)
        }
    }
}
