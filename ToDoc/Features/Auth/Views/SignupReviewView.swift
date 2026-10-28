import SwiftUI

struct SignupReviewView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var state: SignupScreenState
    var onLogin: (() -> Void)?

    var body: some View {
        AuthFormScreen(title: "입력한 정보를 확인해 주세요", progress: state.step.progress,
                       onBack: { state.onAction?(.back) }) {
            VStack(alignment: .leading, spacing: 10) {
                Text("사용자 정보").appTypography(.labelLarge)
                VStack(alignment: .leading, spacing: 30) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("이름").appTypography(.caption)
                            Text(state.name).appTypography(.title)
                        }
                        .padding(.top, 16)
                        Spacer(minLength: 8)
                        Menu {
                            Button("기본 정보 수정") { state.onAction?(.editBasicInfo) }
                            Button("진단 정보 수정") { state.onAction?(.editDiagnosis) }
                        } label: {
                            Text("수정").appTypography(.label)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(state.isWorking || state.isAccountLocked || state.onAction == nil)
                        .accessibilityLabel("입력 정보 수정")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        informationPair {
                            if let birthday = state.birthdayText {
                                information("생년월일", birthday)
                                    .accessibilityValue(state.age.map { "만 \($0)세" } ?? "")
                            }
                            if let sex = state.sex { information("성별", sex.title) }
                        }
                        informationPair {
                            information("암종", state.cancerTitle)
                            information("병기", state.stageTitle)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
                .overlay { RoundedRectangle(cornerRadius: 30).strokeBorder(AppColors.Semantic.Border.default, lineWidth: 1) }
            }
        } footer: {
            if let error = state.errorMessage { AuthMessage(text: error) }
            AuthActionButton(state.isAccountLocked ? "가입 이어서 진행하기" : "확인하고 가입 마치기", isLoading: state.isWorking) {
                state.onAction?(.submit)
            }
            .disabled(state.isWorking || state.onAction == nil)
            if state.isAccountLocked, let onLogin {
                AppActions.TextButton("로그인으로 돌아가기", action: onLogin)
                    .disabled(state.isWorking)
            }
        }
    }

    private func information(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).appTypography(.caption)
            Text(value).appTypography(.labelLarge)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func informationPair<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        return layout { content() }
    }
}
