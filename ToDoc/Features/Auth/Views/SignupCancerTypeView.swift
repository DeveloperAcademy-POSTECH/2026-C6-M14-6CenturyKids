import SwiftUI

struct SignupCancerTypeView: View {
    @Bindable var state: SignupScreenState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        SignupStepScreen(state: state, title: "어떤 암을\n진단받으셨나요?") {
            AuthTextField(title: "암 이름 검색", placeholder: "암 이름 검색", text: $state.cancerSearch, keyboard: .default)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.item), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: AppSpacing.item) {
                ForEach(state.filteredCancerTypes, id: \.self) { type in
                    AuthChoice(title: type.title, isSelected: state.cancerType == type) {
                        state.cancerType = type
                    }
                }
            }
            if state.filteredCancerTypes.isEmpty {
                Text("검색 결과가 없어요. 암종을 모르시면 아래 항목을 선택해 주세요.").appTextStyle(.caption)
            }
            AuthChoice(title: CarcinomaType.unknown.displayName, isSelected: state.cancerType == .unknown) {
                state.cancerType = .unknown
            }
            Text("가입 후에도 내 정보에서 수정할 수 있어요.").appTextStyle(.caption)
                .foregroundStyle(AppColors.Text.secondary)
        }
    }
}
