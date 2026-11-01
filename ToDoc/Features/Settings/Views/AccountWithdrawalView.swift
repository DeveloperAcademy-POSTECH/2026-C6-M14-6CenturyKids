import AuthenticationServices
import SwiftUI

struct AccountWithdrawalView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AccountWithdrawalViewModel
    @State private var showsConfirmation = false

    private var isBusy: Bool { viewModel.isWithdrawing }

    init(viewModel: AccountWithdrawalViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        SettingsScreen(title: "회원 탈퇴", isSaving: isBusy, cancel: { dismiss() }) {
            if viewModel.isLoading {
                ProgressView("가입 정보를 확인하고 있어요")
            } else if let provider = viewModel.signUpProvider {
                switch provider {
                case .email:
                    Text("비밀번호 재확인").settingsText(16, bold: true)
                    Text("안전한 탈퇴를 위해 비밀번호를 다시 한 번 입력해주세요.").settingsText(14).foregroundStyle(SettingsPalette.caption)
                    VStack(spacing: 0) {
                        SettingsPasswordField(title: "비밀번호", text: $viewModel.password, contentType: .password)
                    }.background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 26)).disabled(isBusy)
                    SettingsFeedback(busy: isBusy, error: viewModel.errorMessage)
                    Button { showsConfirmation = true } label: { Text("회원 탈퇴").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
                        .disabled(viewModel.password.isEmpty || isBusy)
                    
                case .apple:
                    Text("재인증").settingsText(16, bold: true)
                    Text("아래 버튼을 눌러 사용자 본인을 확인하면 탈퇴 처리가 완료돼요.").settingsText(14).foregroundStyle(SettingsPalette.caption)
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = []
                    } onCompletion: { result in
                        Task { await viewModel.handleAppleAuthorization(result) }
                    }
                    .disabled(isBusy)
                    .frame(height: 54)
                    .cornerRadius(14)
                    
                case .kakao:
                    Text("카카오 로그인 계정 탈퇴 준비 중").settingsText(16, bold: true)
                }
            }
        }
        .alert("정말 탈퇴 하시겠습니까?", isPresented: $showsConfirmation) {
            Button("취소", role: .cancel) { }
            Button("확인", role: .destructive) {
                Task { await viewModel.withdrawEmailAccount() }
            }.disabled(isBusy)
        } message: { Text("앱 내 모든 데이터는 복구가 불가능합니다") }
        .onDisappear { viewModel.password = "" }
        .onChange(of: viewModel.didWithdraw) { _, didWithdraw in
            guard didWithdraw else { return }
            dismiss()
        }
        .task {
            await viewModel.loadSignUpProvider()
        }
    }
}

#if DEBUG
#Preview("이메일 회원 탈퇴") {
    NavigationStack {
        AccountWithdrawalView(
            viewModel: AccountWithdrawalViewModel(
                authRepository: PreviewAuthRepository(provider: .email),
                authSession: AuthSessionState()
            )
        )
    }
}

#Preview("Apple 회원 탈퇴") {
    NavigationStack {
        AccountWithdrawalView(
            viewModel: AccountWithdrawalViewModel(
                authRepository: PreviewAuthRepository(provider: .apple),
                authSession: AuthSessionState()
            )
        )
    }
}

#Preview("Kakao 회원 탈퇴") {
    NavigationStack {
        AccountWithdrawalView(
            viewModel: AccountWithdrawalViewModel(
                authRepository: PreviewAuthRepository(provider: .kakao),
                authSession: AuthSessionState()
            )
        )
    }
}
#endif
