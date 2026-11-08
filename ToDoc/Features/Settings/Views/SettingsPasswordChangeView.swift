import SwiftUI

/// 로그인한 사용자의 비밀번호 변경 UI. 확인·변경·로그아웃은 주입된 동작이 담당합니다.
struct SettingsPasswordChangeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var showsConfirmation = false
    var isSaving = false
    var didSave = false
    var currentPasswordError: String?
    var newPasswordError: String?
    var errorMessage: String?
    var confirmationMessage: String?
    var onConfirm: ((String, String, String) -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        SettingsScreen(title: "비밀번호 재설정", isSaving: isSaving, cancel: { dismiss() }) {
            VStack(alignment: .leading, spacing: 64) {
                passwordGroup(title: "현재 비밀번호", subtitle: "사용중인 비밀번호를 입력해주세요") {
                    SettingsPasswordField(title: "현재 비밀번호", text: $currentPassword, contentType: .password)
                    SettingsFeedback(error: currentPasswordError)
                }
                passwordGroup(title: "새 비밀번호 입력", subtitle: "영문·숫자를 포함해 8~20자") {
                    VStack(spacing: 0) {
                        SettingsPasswordField(title: "새 비밀번호를 입력해주세요", text: $newPassword)
                        SettingsDivider()
                        SettingsPasswordField(title: "비밀번호를 한번 더 입력해주세요", text: $confirmation)
                    }.background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 26))
                    SettingsFeedback(error: newPasswordError ?? mismatchMessage)
                }
            }.disabled(isSaving)
            SettingsFeedback(busy: isSaving, error: errorMessage)
            Button { showsConfirmation = true } label: { Text("확인").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
                .frame(maxWidth: .infinity).disabled(!canReview || isSaving)
                .accessibilityIdentifier("settings.password.review")
            if onConfirm == nil {
                Text("비밀번호 확인·변경 기능 연결 준비 중이에요.").settingsText(13).foregroundStyle(SettingsPalette.caption)
            }
        }
        .alert("비밀번호를 변경 하시겠습니까?", isPresented: $showsConfirmation) {
            Button("취소", role: .cancel) { }
            Button("확인", role: .destructive) {
                guard canReview, !isSaving else { return }
                onConfirm?(currentPassword, newPassword, confirmation)
            }.disabled(onConfirm == nil || isSaving)
        } message: {
            if let confirmationMessage { Text(confirmationMessage) }
            else if onConfirm == nil { Text("현재는 입력 화면만 준비되어 있으며 비밀번호를 변경하지 않아요.") }
        }
        .onChange(of: didSave) { _, saved in if saved { clearPasswords(); dismiss() } }
        .onDisappear { clearPasswords(); onCancel?() }
    }
    private var canReview: Bool { !currentPassword.isEmpty && !newPassword.isEmpty && confirmation == newPassword }
    private var mismatchMessage: String? {
        !confirmation.isEmpty && confirmation != newPassword ? "비밀번호가 일치하지 않습니다" : nil
    }
    private func clearPasswords() { currentPassword = ""; newPassword = ""; confirmation = "" }
    private func passwordGroup<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).settingsText(16, bold: true)
            Text(subtitle).settingsText(14).foregroundStyle(SettingsPalette.caption)
            content()
        }
    }
}

/// 보안 입력과 표시 전환만 처리합니다. 입력값을 저장하거나 출력하지 않습니다.
struct SettingsPasswordField: View {
    let title: String
    @Binding var text: String
    var contentType: UITextContentType = .newPassword
    @State private var isVisible = false
    @FocusState private var isFocused: Bool
    var body: some View {
        HStack {
            Group {
                if isVisible { TextField(title, text: $text) }
                else { SecureField(title, text: $text) }
            }.textContentType(contentType).textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.done).settingsText().accessibilityLabel(title).focused($isFocused)
                .onSubmit { isFocused = false }
            Button { isVisible.toggle() } label: { Image(systemName: isVisible ? "eye" : "eye.slash") }
                .foregroundStyle(SettingsPalette.secondary).frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(isVisible ? "비밀번호 숨기기" : "비밀번호 표시")
        }.padding(.leading, 16).padding(.trailing, 6).frame(minHeight: 52)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 26))
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if isFocused { Spacer(); Button("입력 완료") { isFocused = false } }
                }
            }
    }
}

#Preview("비밀번호 변경 · UI만") { NavigationStack { SettingsPasswordChangeView() } }
