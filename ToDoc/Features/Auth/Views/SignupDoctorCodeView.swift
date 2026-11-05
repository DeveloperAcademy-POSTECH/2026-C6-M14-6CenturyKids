import SwiftUI

struct SignupDoctorCodeView: View {
    @Bindable var state: SignupScreenState
    @State private var showsHelp = false

    var body: some View {
        AuthFormScreen(title: "의사 코드를 입력해 주세요", progress: state.step.progress,
                       onBack: { state.onAction?(.back) }, subtitle: "병원에서 받은 인증 코드예요",
                       contentSpacing: 26) {
            AuthTextField(title: "의사 코드", placeholder: "의사코드 입력", text: $state.doctorCode,
                          error: state.hasAttemptedStep ? state.currentValidationError : nil)
                .disabled(state.isWorking)
                .appTextLimit($state.doctorCode, maximum: 8)
            Button { showsHelp = true } label: {
                Label("코드를 받지 못했나요?", systemImage: "exclamationmark.circle.fill")
                    .underline().appTypography(.label)
                    .foregroundStyle(AppColors.Semantic.Text.placeholder)
                    .frame(minHeight: AppMetrics.Control.minimumHitSize)
            }
            Text("의사에게 받은 영문·숫자 8자리 코드예요.\n대소문자를 그대로 입력해 주세요.\n코드가 없다면 지금은 건너뛸 수 있어요.")
                .appTypography(.bodySmall)
                .foregroundStyle(AppColors.Semantic.Text.sub)
            if let error = state.errorMessage { AuthMessage(text: error) }
        } footer: {
            AuthActionButton("코드 확인", isLoading: state.isWorking) {
                state.onAction?(.verifyDoctorCode)
            }
            .disabled(state.isWorking || state.onAction == nil)
            Button("지금은 건너뛰기") { state.onAction?(.skipDoctorCode) }
                .appTypography(.label)
                .foregroundStyle(AppColors.Semantic.Text.sub)
                .frame(minHeight: AppMetrics.Control.minimumHitSize)
        }
        .alert("의사 연결 코드", isPresented: $showsHelp) {
            Button("확인", role: .cancel) {}
        } message: { Text("담당 의사에게 연결 코드를 요청해 주세요. 지금은 건너뛰고 나중에 연결할 수도 있어요.") }
    }
}
