import SwiftUI

struct SignupReviewView: View {
    @Bindable var state: SignupScreenState
    var onLogin: (() -> Void)?
    var onRestart: (() -> Void)?
    @State private var confirmsRestart = false
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
            if state.isAccountLocked, let onLogin {
                Button("로그인으로 돌아가기", action: onLogin)
                    .appTextStyle(.caption).frame(minHeight: 44).disabled(state.isWorking)
            }
            if state.isAccountLocked, onRestart != nil {
                Button("처음부터 다시 작성") { confirmsRestart = true }
                    .appTextStyle(.caption).frame(minHeight: 44).disabled(state.isWorking)
            }
        }
        .alert("가입 정보를 다시 작성할까요?", isPresented: $confirmsRestart) {
            Button("계속 이어서 진행", role: .cancel) {}
            Button("다시 작성", role: .destructive) { onRestart?() }
        } message: {
            Text("입력한 내용과 이 앱의 저장 진행 상태가 지워져요. 서버에 이미 만들어진 계정은 삭제되지 않아요. 기존 계정이 있다면 로그인이나 비밀번호 찾기를 이용해 주세요.")
        }
    }
}
