import SwiftUI

struct SignupDoctorCodeView: View {
    @Bindable var model: SignupViewModel
    @State private var request: Task<Void, Never>?
    @State private var showsHelp = false

    var body: some View {
        AuthFormScreen(title: "의사 연결 코드를\n입력해 주세요", progress: model.step.progress, onBack: { model.back() }) {
            Text("의사에게 받은 6자리 코드예요.").appTextStyle(.caption)
            AuthTextField(title: "연결 코드", placeholder: "예: A12B34", text: $model.doctorCode,
                          error: model.hasAttemptedStep ? model.currentValidationError : nil)
                .disabled(model.isWorking)
            Button { showsHelp = true } label: {
                Text("코드는 어디에서 받나요?").underline()
            }
            .appTextStyle(.caption).frame(minHeight: 44)
            if let error = model.errorMessage { AuthMessage(text: error) }
        } footer: {
            Button {
                request = Task { await model.verifyDoctorCode() }
            } label: { AuthSubmitLabel(title: "코드 확인", isLoading: model.isWorking) }
                .buttonStyle(AppButtonStyle()).disabled(model.isWorking)
            Button("지금은 건너뛰기") { request?.cancel(); model.skipDoctorCode() }
                .appTextStyle(.caption).frame(minHeight: 44)
        }
        .alert("의사 연결 코드", isPresented: $showsHelp) {
            Button("확인", role: .cancel) {}
        } message: { Text("담당 의사에게 연결 코드를 요청해 주세요. 지금은 건너뛰고 나중에 연결할 수도 있어요.") }
        .onDisappear { request?.cancel() }
    }
}
