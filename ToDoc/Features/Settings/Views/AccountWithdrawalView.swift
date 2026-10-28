import AuthenticationServices
import SwiftUI

/// 비밀번호 재확인과 Apple 재인증을 제공하는 탈퇴 화면.
struct AccountWithdrawalView: View {
    var authRepository: (any AuthRepository)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var showsConfirmation = false
    var email: String?
    var isSubmitting = false
    var errorMessage: String?
    var onConfirm: ((String) -> Void)?
    var onWithdrawalCompleted: (() -> Void)?
    @State private var isWithdrawing = false
    @State private var withdrawalError: String?
    private var isBusy: Bool { isSubmitting || isWithdrawing }

    var body: some View {
        SettingsScreen(title: "회원 탈퇴", isSaving: isBusy, cancel: { dismiss() }) {
            Text("비밀번호 재확인").settingsText(16, bold: true)
            Text("안전한 탈퇴를 위해 비밀번호를 다시 한 번 입력해주세요").settingsText(14).foregroundStyle(SettingsPalette.caption)
            VStack(spacing: 0) {
                if let email {
                    Text(email).settingsText().frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding(.horizontal, 16)
                    SettingsDivider()
                }
                SettingsPasswordField(title: "비밀번호", text: $password, contentType: .password)
            }.background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 26)).disabled(isBusy)
            SettingsFeedback(busy: isBusy, error: withdrawalError ?? errorMessage)
            Button { showsConfirmation = true } label: { Text("회원 탈퇴").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
                .disabled(password.isEmpty || isBusy)
            
            HStack(spacing: 12) {
                Rectangle().fill(Color(red: 222.0 / 255, green: 227.0 / 255, blue: 219.0 / 255)).frame(height: 1)
                Text("또는 다음으로 계속")
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .layoutPriority(1)
                Rectangle().fill(Color(red: 222.0 / 255, green: 227.0 / 255, blue: 219.0 / 255)).frame(height: 1)
            }
            .font(Font(AppTypography.font(for: .captionRegular, size: 16)))
            .foregroundStyle(Color(white: 74.0 / 255))
            .frame(minHeight: 24)
            .padding(.top, 100)
            
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = []
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let codeData = credential.authorizationCode,
                          let authorizationCode = String(data: codeData, encoding: .utf8),
                          !authorizationCode.isEmpty else {
                        print("Apple 인증 코드를 받지 못했어요.")
                        return
                    }
                    
                    Task {
                        guard let authRepository else {
                            print("탈퇴 기능이 연결되지 않았어요.")
                            return
                        }
                        do {
                            try await authRepository.withdrawAppleAccount(authorizationCode: authorizationCode)
                            
                            print("회원 탈퇴 성공")
                        } catch {
                            print("회원 탈퇴 실패: ", error)
                        }
                    }
                    
                case .failure(let error):
                    if let appleError = error as? ASAuthorizationError,
                       appleError.code == .canceled {
                        return
                    }
                    
                    print("Apple 재인증 실패: ", error.localizedDescription)
                }
            }
            .frame(height: 54)
            .cornerRadius(14)
        }
        .alert("정말 탈퇴 하시겠습니까?", isPresented: $showsConfirmation) {
            Button("취소", role: .cancel) { }
            Button("확인", role: .destructive) {
                guard !password.isEmpty, !isBusy else { return }
                if let onConfirm {
                    onConfirm(password)
                } else {
                    Task { await withdrawEmailAccount() }
                }
            }.disabled(isBusy)
        } message: { Text("앱 내 모든 데이터는 복구가 불가능합니다") }
            .onDisappear { password = "" }
    }

    @MainActor
    private func withdrawEmailAccount() async {
        guard !isBusy else { return }
        guard let authRepository else {
            withdrawalError = "탈퇴 기능이 연결되지 않았어요. 실제 앱에서 다시 시도해 주세요."
            return
        }
        isWithdrawing = true
        withdrawalError = nil
        defer { isWithdrawing = false }

        do {
            let currentUserId = try await authRepository.getCurrentUserId()
            guard let currentEmail = try await authRepository.getCurrentUserEmail(), !currentEmail.isEmpty else {
                withdrawalError = "계정 이메일을 확인하지 못했어요. 다시 로그인해 주세요."
                return
            }
            let verifiedUserId = try await authRepository.signIn(email: currentEmail, password: password)
            guard verifiedUserId == currentUserId else {
                withdrawalError = "계정 정보를 확인하지 못했어요. 다시 로그인해 주세요."
                return
            }
            try await authRepository.deleteAccount()
            password = ""
            onWithdrawalCompleted?()
            dismiss()
        } catch {
            withdrawalError = "탈퇴하지 못했어요. 비밀번호와 네트워크 연결을 확인해 주세요."
        }
    }
}

#Preview("회원 탈퇴 · UI만") { NavigationStack { AccountWithdrawalView() } }
