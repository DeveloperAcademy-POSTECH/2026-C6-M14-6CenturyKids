import SwiftUI

struct SignupTermsView: View {
    @Bindable var state: SignupScreenState
    @State private var selectedTerm: SignupTerm?

    var body: some View {
        SignupStepScreen(state: state, title: "이용약관에\n동의해 주세요", buttonTitle: "동의하고 다음") {
            VStack(spacing: AppSpacing.item) {
                Toggle(isOn: Binding(get: { state.allTermsAccepted }, set: { state.acceptedTerms = $0 ? Set(SignupTerm.allCases) : [] })) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("전체 동의").appTextStyle(.label)
                        Text("필수와 선택 항목 모두 동의").appTextStyle(.caption)
                    }
                }
                .toggleStyle(AuthCheckboxToggleStyle()).padding(AppSpacing.Auth.informationPadding)
                .appSurface(.authInformation)
                ForEach(SignupTerm.allCases) { term in
                    HStack(alignment: .center, spacing: AppSpacing.tight) {
                        Toggle(isOn: Binding(
                            get: { state.acceptedTerms.contains(term) },
                            set: { accepted in
                                if accepted { state.acceptedTerms.insert(term) }
                                else { state.acceptedTerms.remove(term) }
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
            if !state.hasRequiredTermsContent {
                Text("약관 본문은 준비 중이에요. 약관이 제공되면 가입을 완료할 수 있어요.")
                    .appTextStyle(.caption).foregroundStyle(AppColors.Text.secondary)
            }
        }
        .sheet(item: $selectedTerm) { term in
            TermsDetailView(title: term.title, content: state.termsContent[term])
        }
    }
}
