import SwiftUI

struct PasswordCodeEntryView: View {
    @Bindable var state: PasswordChangeScreenState
    var onConfirm: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("인증 코드 입력")
                        .settingsText(17, bold: true)
                    Text("이메일로 전송받은 인증 코드를 입력해주세요")
                        .settingsText(14)
                        .foregroundStyle(SettingsPalette.secondary)

                    TextField("인증 코드", text: $state.verificationCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .settingsText()
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .disabled(state.isSendingCode || state.isSaving)
                        .accessibilityIdentifier("settings.password.code")

                    SettingsFeedback(
                        busy: state.isSendingCode,
                        error: state.codeError ?? state.errorMessage
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 48)
            }
            .scrollDismissesKeyboard(.interactively)

            Button(action: onConfirm) {
                Text("확인")
                    .settingsText(17, bold: true)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(.white)
                    .background(.blue, in: Capsule())
            }
            .disabled(state.isSendingCode || state.isSaving)
            .accessibilityIdentifier("settings.password.codeConfirm")
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .foregroundStyle(SettingsPalette.primary)
        .background(SettingsPalette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image("SettingsBack")
                    .resizable()
                    .frame(width: 10, height: 19)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("뒤로 가기")
            .accessibilityIdentifier("settings.password.back")

            Spacer()
            Text("비밀번호 재설정")
                .settingsText(17, bold: true)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
}

#Preview("인증 코드 입력") {
    NavigationStack {
        PasswordCodeEntryView(state: PasswordChangeScreenState())
    }
}

#Preview("입력 오류") {
    let state = PasswordChangeScreenState()
    state.verificationCode = "123456"
    state.codeError = "인증코드가 올바르지 않아요. 다시 확인해 주세요."
    return NavigationStack {
        PasswordCodeEntryView(state: state)
    }
}
