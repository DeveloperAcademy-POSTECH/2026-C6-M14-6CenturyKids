import AuthenticationServices
import SwiftUI

/// 비밀번호 재확인과 Apple 재인증을 제공하는 탈퇴 화면.
struct AccountWithdrawalView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AccountWithdrawalViewModel
    @State private var showsConfirmation = false

    private var isBusy: Bool { viewModel.isWithdrawing }

    init(viewModel: AccountWithdrawalViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        SettingsScreen(title: "회원 탈퇴", isSaving: isBusy, cancel: { dismiss() }) {
            Text("비밀번호 재확인").settingsText(16, bold: true)
            Text("안전한 탈퇴를 위해 비밀번호를 다시 한 번 입력해주세요").settingsText(14).foregroundStyle(SettingsPalette.caption)
            VStack(spacing: 0) {
                SettingsPasswordField(title: "비밀번호", text: $viewModel.password, contentType: .password)
            }.background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 26)).disabled(isBusy)
            SettingsFeedback(busy: isBusy, error: viewModel.errorMessage)
            Button { showsConfirmation = true } label: { Text("회원 탈퇴").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
                .disabled(viewModel.password.isEmpty || isBusy)
            
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
                Task { await viewModel.handleAppleAuthorization(result) }
            }
            .disabled(isBusy)
            .frame(height: 54)
            .cornerRadius(14)
        }
        .alert("정말 탈퇴 하시겠습니까?", isPresented: $showsConfirmation) {
            Button("취소", role: .cancel) { }
            Button("확인", role: .destructive) {
                confirmWithdrawal()
            }.disabled(isBusy)
        } message: { Text("앱 내 모든 데이터는 복구가 불가능합니다") }
        .onDisappear { viewModel.password = "" }
        .onChange(of: viewModel.didWithdraw) { _, didWithdraw in
            guard didWithdraw else { return }
            dismiss()
        }
    }

    private func confirmWithdrawal() {
        guard !viewModel.password.isEmpty, !isBusy else { return }
        Task { await viewModel.withdrawEmailAccount() }
    }
}

#if DEBUG
#Preview("회원 탈퇴") {
    NavigationStack {
        AccountWithdrawalView(viewModel: AccountWithdrawalViewModel(authRepository: PreviewAuthRepository(), authSession: AuthSessionState()))
    }
}
#endif
