import SwiftUI

struct SignupTermsView: View {
    @Bindable var model: SignupViewModel
    @State private var selectedTerm: SignupTerm?

    var body: some View {
        SignupStepScreen(model: model, title: "이용약관에\n동의해 주세요", buttonTitle: "동의하고 다음") {
            VStack(spacing: 12) {
                Toggle(isOn: Binding(get: { model.allTermsAccepted }, set: { model.setAllTerms($0) })) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("전체 동의").appTextStyle(.label)
                        Text("필수와 선택 항목 모두 동의").appTextStyle(.caption)
                    }
                }
                .toggleStyle(AuthCheckboxToggleStyle()).padding(20)
                .background(AppColors.secondary, in: RoundedRectangle(cornerRadius: 20))
                ForEach(SignupTerm.allCases) { term in
                    HStack(alignment: .center, spacing: 4) {
                        Toggle(isOn: Binding(
                            get: { model.acceptedTerms.contains(term) },
                            set: { accepted in
                                if accepted { model.acceptedTerms.insert(term) }
                                else { model.acceptedTerms.remove(term) }
                            }
                        )) {
                            Text(term.fullTitle).appTextStyle(.caption)
                        }
                        .toggleStyle(AuthCheckboxToggleStyle())
                        Button { selectedTerm = term } label: {
                            Image(systemName: "chevron.right").frame(width: 44, height: 48)
                        }.accessibilityLabel("\(term.title) 보기")
                    }
                }
            }
            if !model.hasRequiredTermsContent {
                Text("약관 본문은 준비 중이에요. 약관이 제공되면 가입을 완료할 수 있어요.")
                    .appTextStyle(.caption).foregroundStyle(AppColors.Text.secondary)
            }
        }
        .sheet(item: $selectedTerm) { term in
            TermsDetailView(title: term.title, content: model.termsContent[term])
        }
    }
}
