import SwiftUI

/// Figma의 탈퇴 확인 화면. 실제 탈퇴는 외부에서 연결하기 전까지 실행할 수 없습니다.
struct AccountWithdrawalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var showsConfirmation = false
    var email: String?
    var isSubmitting = false
    var errorMessage: String?
    var onConfirm: ((String) -> Void)?
    var body: some View {
        SettingsScreen(title: "회원 탈퇴", isSaving: isSubmitting, cancel: { dismiss() }) {
            Text("비밀번호 재확인").settingsText(16, bold: true)
            Text("안전한 탈퇴를 위해 비밀번호를 다시 한 번 입력해주세요").settingsText(14).foregroundStyle(SettingsPalette.caption)
            VStack(spacing: 0) {
                if let email {
                    Text(email).settingsText().frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding(.horizontal, 16)
                    SettingsDivider()
                }
                SettingsPasswordField(title: "비밀번호", text: $password, contentType: .password)
            }.background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 26)).disabled(isSubmitting)
            SettingsFeedback(busy: isSubmitting, error: errorMessage)
            Button { showsConfirmation = true } label: { Text("회원 탈퇴").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
                .disabled(password.isEmpty || isSubmitting)
            if onConfirm == nil {
                Text("탈퇴 기능 연결 준비 중이에요. 계정과 기록은 삭제되지 않아요.").settingsText(13).foregroundStyle(SettingsPalette.caption)
            }
        }
        .alert("정말 탈퇴 하시겠습니까?", isPresented: $showsConfirmation) {
            Button("취소", role: .cancel) { }
            Button("확인", role: .destructive) {
                guard !password.isEmpty, !isSubmitting else { return }
                onConfirm?(password)
            }.disabled(onConfirm == nil || isSubmitting)
        } message: { Text("앱 내 모든 데이터는 복구가 불가능합니다") }
        .onDisappear { password = "" }
    }
}

#Preview("회원 탈퇴 · UI만") { NavigationStack { AccountWithdrawalView() } }
