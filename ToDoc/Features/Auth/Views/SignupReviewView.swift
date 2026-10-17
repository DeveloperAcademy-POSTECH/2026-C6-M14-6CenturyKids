import SwiftUI

struct SignupReviewView: View {
    @Bindable var state: SignupScreenState
    var onLogin: (() -> Void)?
    var body: some View {
        AuthFormScreen(title: "입력한 정보가\n맞나요?", progress: state.step.progress, onBack: { state.onAction?(.back) }) {
            SignupSummaryCard(title: "기본 정보", edit: { state.onAction?(.editBasicInfo) }) {
                Text(state.name)
                if let birthday = state.birthdayText, let age = state.age {
                    Text("\(birthday) · 만 \(age)세")
                }
                if let sex = state.sex { Text(sex.title) }
            }.disabled(state.isWorking || state.isAccountLocked || state.onAction == nil)
            SignupSummaryCard(title: "진단 정보", edit: { state.onAction?(.editDiagnosis) }) {
                Text("\(state.cancerTitle) · \(state.stageTitle)")
            }.disabled(state.isWorking || state.isAccountLocked || state.onAction == nil)
            if let error = state.errorMessage { AuthMessage(text: error) }
        } footer: {
            Button { state.onAction?(.submit) } label: {
                AuthSubmitLabel(title: state.isAwaitingEmailConfirmation ? "확인 후 가입 이어가기" : (state.isAccountLocked ? "가입 이어서 진행하기" : "확인하고 가입 마치기"), isLoading: state.isWorking)
            }
            .buttonStyle(AppButtonStyle()).disabled(state.isWorking || state.onAction == nil)
            if state.isAwaitingEmailConfirmation {
                Button("인증 메일 다시 받기") { state.onAction?(.resendConfirmation) }
                    .appTextStyle(.caption).frame(minHeight: 44).disabled(state.isWorking)
            }
            if state.isAccountLocked, let onLogin {
                Button("로그인으로 돌아가기", action: onLogin)
                    .appTextStyle(.caption).frame(minHeight: 44).disabled(state.isWorking)
            }
        }
    }
}
