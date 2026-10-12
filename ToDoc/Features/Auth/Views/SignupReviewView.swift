import SwiftUI

struct SignupReviewView: View {
    @Bindable var model: SignupViewModel
    @State private var request: Task<Void, Never>?
    var body: some View {
        AuthFormScreen(title: "입력한 정보가\n맞나요?", progress: model.step.progress, onBack: { model.back() }) {
            SignupSummaryCard(title: "기본 정보", edit: { model.editBasicInfo() }) {
                Text(AuthFormValidation.trimmed(model.name))
                if let birthday = model.birthdayText, let age = model.age {
                    Text("\(birthday) · 만 \(age)세")
                }
                if let sex = model.sex { Text(sex.title) }
            }.disabled(model.isWorking)
            SignupSummaryCard(title: "진단 정보", edit: { model.editDiagnosis() }) {
                Text("\(model.cancerTitle) · \(model.stageTitle)")
            }.disabled(model.isWorking)
            if let error = model.errorMessage { AuthMessage(text: error) }
        } footer: {
            Button { request = Task { await model.submit() } } label: {
                AuthSubmitLabel(title: "확인하고 가입 마치기", isLoading: model.isWorking)
            }
            .buttonStyle(AppButtonStyle()).disabled(model.isWorking)
        }
        .onDisappear { request?.cancel() }
    }
}
