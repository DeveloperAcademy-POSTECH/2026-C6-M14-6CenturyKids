import AuthenticationServices
import SwiftUI

/// Figma의 탈퇴 확인 화면. 실제 탈퇴는 외부에서 연결하기 전까지 실행할 수 없습니다.
struct AccountWithdrawalView: View {
    var authRepository: (any AuthRepository)? = nil
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
                guard !password.isEmpty, !isSubmitting else { return }
                onConfirm?(password)
            }.disabled(onConfirm == nil || isSubmitting)
        } message: { Text("앱 내 모든 데이터는 복구가 불가능합니다") }
            .onDisappear { password = "" }
    }
}

#Preview("회원 탈퇴 · UI만") { NavigationStack { AccountWithdrawalView() } }
