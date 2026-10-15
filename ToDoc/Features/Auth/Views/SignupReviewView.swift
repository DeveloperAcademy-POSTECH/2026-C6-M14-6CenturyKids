import SwiftUI

struct SignupReviewView: View {
    @Bindable var state: SignupScreenState
    var body: some View {
        AuthFormScreen(title: "입력한 정보가\n맞나요?", progress: state.step.progress, onBack: { state.onAction?(.back) }) {
            SignupSummaryCard(title: "기본 정보", edit: { state.onAction?(.editBasicInfo) }) {
                Text(state.name)
                if let birthday = state.birthdayText, let age = state.age {
                    Text("\(birthday) · 만 \(age)세")
                }
                if let sex = state.sex { Text(sex.title) }
            }.disabled(state.isWorking || state.onAction == nil)
            SignupSummaryCard(title: "진단 정보", edit: { state.onAction?(.editDiagnosis) }) {
                Text("\(state.cancerTitle) · \(state.stageTitle)")
            }.disabled(state.isWorking || state.onAction == nil)
            if let error = state.errorMessage { AuthMessage(text: error) }
        } footer: {
            Button { state.onAction?(.submit) } label: {
                AuthSubmitLabel(title: "확인하고 가입 마치기", isLoading: state.isWorking)
            }
            .buttonStyle(AppButtonStyle()).disabled(state.isWorking || state.onAction == nil)
        }
    }
}
