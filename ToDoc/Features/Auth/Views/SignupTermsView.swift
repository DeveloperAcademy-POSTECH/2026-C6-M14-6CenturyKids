import SwiftUI

struct SignupTermsView: View {
    @Bindable var state: SignupScreenState
    var onLogin: (() -> Void)?
    var onRestart: (() -> Void)?
    @State private var confirmsRestart = false
    @State private var showsTerms = false

    var body: some View {
        AuthFormScreen(title: "이용약관에 동의해 주세요", progress: state.step.progress, onBack: { state.onAction?(.back) }) {
            VStack(alignment: .leading, spacing: 10) {
                Text("약관 동의").appTypography(.labelLarge)
                Toggle(isOn: Binding(get: { state.allTermsAccepted }, set: { state.acceptedTerms = $0 ? Set(SignupTerm.allCases) : [] })) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("전체 동의").appTypography(.labelLarge)
                        Text("아래 항목을 모두 동의합니다.")
                            .appTypography(.bodySmall)
                            .foregroundStyle(AppColors.Semantic.Text.disabled)
                    }
                }
                .toggleStyle(AuthCheckboxToggleStyle()).padding(16)
                .background(AppColors.Surface.control, in: RoundedRectangle(cornerRadius: 20))
            }
            .disabled(state.isWorking || state.isAccountLocked)
            VStack(spacing: 0) {
                ForEach(SignupTerm.allCases) { term in
                    Toggle(isOn: Binding(
                        get: { state.acceptedTerms.contains(term) },
                        set: { accepted in
                            if accepted { state.acceptedTerms.insert(term) }
                            else { state.acceptedTerms.remove(term) }
                        }
                    )) {
                        Text(term.fullTitle).appTypography(.label)
                            .foregroundStyle(AppColors.Semantic.Text.placeholder)
                    }
                    .toggleStyle(AuthCheckboxToggleStyle())
                    .frame(minHeight: AppMetrics.Control.minimumHitSize)
                }
            }
            .disabled(state.isWorking || state.isAccountLocked)

            Button("전문 보기") { showsTerms = true }
                .appTypography(.label)
                .underline()
                .frame(minHeight: AppMetrics.Control.minimumHitSize)
                .accessibilityLabel("이용약관 전문 보기")

        } footer: {
            if let error = state.errorMessage { AuthMessage(text: error) }
            if !state.isEmailAlreadyRegistered {
                AuthActionButton("다음", isLoading: state.isWorking, loadingTitle: "다음") {
                    state.onAction?(.next)
                }
                    .disabled(!state.canProceedFromTerms || state.isWorking || state.onAction == nil)
            }
            if !state.isWorking, state.isEmailAlreadyRegistered, onRestart != nil {
                Button("다른 이메일로 다시 작성") { confirmsRestart = true }
                    .appTextStyle(.caption).frame(minHeight: AppMetrics.Control.minimumHitSize)
                    .disabled(state.isWorking)
            }
            if !state.isWorking, state.isAccountLocked || state.errorMessage != nil, let onLogin {
                AppActions.Button("로그인으로 이동", kind: .secondary, action: onLogin)
                    .disabled(state.isWorking)
            }
        }
        .alert("다른 이메일로 가입할까요?", isPresented: $confirmsRestart) {
            Button("취소", role: .cancel) {}
            Button("다시 작성") { onRestart?() }
        } message: {
            Text("현재 입력을 지우고 처음부터 작성합니다. 기존 계정은 그대로 유지됩니다.")
        }
        .sheet(isPresented: $showsTerms) {
            TermsWebView()
                .ignoresSafeArea()
        }
    }
}
