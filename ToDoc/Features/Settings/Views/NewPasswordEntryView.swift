import SwiftUI

struct NewPasswordEntryView: View {
    @Bindable var state: PasswordChangeScreenState

    @State private var showsChangeConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("새 비밀번호 입력")
                        .settingsText(17, bold: true)
                    Text("영문, 숫자, 특수문자 조합 8~32자")
                        .settingsText(14)
                        .foregroundStyle(SettingsPalette.secondary)

                    VStack(spacing: 0) {
                        SecureField("새 비밀번호를 입력해주세요", text: $state.newPassword)
                            .textContentType(.newPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .settingsText()
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .disabled(state.isSaving)
                            .accessibilityIdentifier("settings.password.new")

                        SettingsDivider()

                        SecureField("비밀번호를 한 번 더 입력해주세요", text: $state.passwordConfirmation)
                            .textContentType(.newPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .settingsText()
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .disabled(state.isSaving)
                            .accessibilityIdentifier("settings.password.confirmation")
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 24))

                    SettingsFeedback(busy: state.isSaving, error: validationMessage)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 48)
            }
            .scrollDismissesKeyboard(.interactively)

            Button {
                showsChangeConfirmation = true
            } label: {
                Text("확인")
                    .settingsText(17, bold: true)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(.white)
                    .background(.blue, in: Capsule())
            }
            .disabled(state.isSaving || !state.canSubmitPassword || state.onSave == nil)
            .accessibilityIdentifier("settings.password.changeConfirm")
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .foregroundStyle(SettingsPalette.primary)
        .background(SettingsPalette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert("비밀번호를 변경하시겠습니까?", isPresented: $showsChangeConfirmation) {
            Button("취소", role: .cancel) {}
            Button("확인") { state.onSave?() }
        }
        .onChange(of: state.newPassword) { _, _ in
            state.onInputChanged?()
        }
        .onChange(of: state.passwordConfirmation) { _, _ in
            state.onInputChanged?()
        }
    }

    private var validationMessage: String? {
        state.newPasswordError ?? state.confirmationError ?? state.errorMessage
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image("SettingsBack")
                    .resizable()
                    .frame(width: 10, height: 19)
                    .frame(width: 44, height: 44)
            }
            .disabled(state.isSaving)
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

#Preview("새 비밀번호 입력") {
    let state = PasswordChangeScreenState()
    state.onSave = {}
    return NavigationStack {
        NewPasswordEntryView(state: state)
    }
}

#Preview("비밀번호 형식 오류") {
    let state = PasswordChangeScreenState()
    state.newPasswordError = "영문, 숫자, 특수문자를 조합해 8~32자로 입력해 주세요."
    state.onSave = {}
    return NavigationStack {
        NewPasswordEntryView(state: state)
    }
}

#Preview("비밀번호 불일치") {
    let state = PasswordChangeScreenState()
    state.confirmationError = "새 비밀번호가 일치하지 않아요."
    state.onSave = {}
    return NavigationStack {
        NewPasswordEntryView(state: state)
    }
}
