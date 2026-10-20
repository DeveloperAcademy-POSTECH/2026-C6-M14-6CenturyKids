import SwiftUI

struct SignupDoctorCodeView: View {
    @Bindable var state: SignupScreenState
    @State private var showsHelp = false

    var body: some View {
        AuthFormScreen(title: "의사 연결 코드를\n입력해 주세요", progress: state.step.progress, onBack: { state.onAction?(.back) }) {
            Text("의사에게 받은 6자리 코드예요.\n코드가 없다면 지금은 건너뛸 수 있어요.").appTextStyle(.caption)
            AuthTextField(title: "연결 코드", placeholder: "예: A12B34", text: $state.doctorCode,
                          error: state.hasAttemptedStep ? state.currentValidationError : nil)
                .disabled(state.isWorking)
            Button { showsHelp = true } label: {
                Text("코드는 어디에서 받나요?").underline().appTextStyle(.caption).frame(minHeight: 44)
            }
            if let error = state.errorMessage { AuthMessage(text: error) }
        } footer: {
            Button {
                state.onAction?(.verifyDoctorCode)
            } label: { AuthSubmitLabel(title: "코드 확인", isLoading: state.isWorking) }
                .buttonStyle(AppButtonStyle()).disabled(state.isWorking || state.onAction == nil)
            Button("지금은 건너뛰기") { state.onAction?(.skipDoctorCode) }
                .appTextStyle(.caption).frame(minHeight: 44)
        }
        .alert("의사 연결 코드", isPresented: $showsHelp) {
            Button("확인", role: .cancel) {}
        } message: { Text("담당 의사에게 연결 코드를 요청해 주세요. 지금은 건너뛰고 나중에 연결할 수도 있어요.") }
    }
}
