import SwiftUI

struct SignupCancerTypeView: View {
    @Bindable var state: SignupScreenState
    var body: some View {
        SignupStepScreen(state: state, title: "어떤 암인지 알려주세요",
                         subtitle: "가입한 후에도 내 정보에서 수정할 수 있어요", contentSpacing: 26) {
            AuthTextField(title: "암 이름 검색", placeholder: "암 이름 검색", text: $state.cancerSearch, keyboard: .default)
            LazyVStack(spacing: 6) {
                ForEach(state.filteredCancerTypes, id: \.self) { type in
                    AuthChoice(title: type.title, isSelected: !state.usesCustomCancer && state.cancerType == type) {
                        state.cancerType = type
                        state.usesCustomCancer = false
                    }
                }
            }
            if state.filteredCancerTypes.isEmpty {
                Text("검색 결과가 없어요. 아래에서 직접 입력하거나 ‘잘 모르겠어요’를 선택해 주세요.")
                    .appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
            }
            AuthChoice(title: "암종 이름 직접 입력", isSelected: state.usesCustomCancer) {
                state.usesCustomCancer = true
            }
            if state.usesCustomCancer {
                AuthTextField(title: "암종 이름", placeholder: "진단받은 암 이름을 입력해 주세요", text: $state.customCancerName)
            }
            AuthChoice(title: CarcinomaType.unknown.displayName, isSelected: !state.usesCustomCancer && state.cancerType == .unknown) {
                state.cancerType = .unknown
                state.usesCustomCancer = false
            }
        }
    }
}
