import SwiftUI

struct SignupCancerTypeView: View {
    @Bindable var model: SignupViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        SignupStepScreen(model: model, title: "어떤 암을\n진단받으셨나요?") {
            AuthTextField(title: "암 이름 검색", placeholder: "암 이름 검색", text: $model.cancerSearch, keyboard: .default)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                ForEach(model.filteredCancerTypes, id: \.self) { type in
                    AuthChoice(title: type.title, isSelected: !model.usesOtherCancer && model.cancerType == type) {
                        model.cancerType = type
                        model.usesOtherCancer = false
                    }
                }
            }
            if model.filteredCancerTypes.isEmpty {
                Text("검색 결과가 없어요. 기타 직접 입력을 선택해 주세요.").appTextStyle(.caption)
            }
            AuthChoice(title: "기타 직접 입력", isSelected: model.usesOtherCancer) { model.usesOtherCancer = true }
            if model.usesOtherCancer {
                AuthTextField(title: "암 이름", placeholder: "진단받은 암 이름을 입력해 주세요", text: $model.otherCancer)
            }
            Text("가입 후에도 내 정보에서 수정할 수 있어요.").appTextStyle(.caption)
                .foregroundStyle(AppColors.Text.secondary)
        }
    }
}
