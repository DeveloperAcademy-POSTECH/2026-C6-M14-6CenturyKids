import AuthenticationServices
import SwiftUI

struct LoginView: View {
    var body: some View { AuthFlowView() }
}

struct LoginFormView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: LoginViewModel
    
    private var state: LoginScreenState {
        viewModel.state
    }
    
    let onSignup: () -> Void
    let onPasswordReset: () -> Void
    var onBack: (() -> Void)? = nil

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("C6")
                    .appFont(.authBrand)
                    .foregroundStyle(AppColors.Auth.brand)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        if let onBack {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left").frame(width: AppMetrics.Control.minimumHitSize, height: AppMetrics.Control.minimumHitSize)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("온보딩으로 돌아가기")
                        }
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 48)

                VStack(alignment: .leading, spacing: 14) {
                    Text("다시 만나서\n반가워요")
                        .appTextStyle(.heading)
                        .accessibilityAddTraits(.isHeader)
                    Text("아래에 정보를 입력해 주세요.")
                        .appTextStyle(.caption)
                        .foregroundStyle(AppColors.Text.secondary)
                }
                .padding(.bottom, 28)

                VStack(spacing: AppSpacing.item) {
                    AuthTextField(title: "이메일", placeholder: "이메일을 입력해 주세요", text: $state.email,
                                  keyboard: .emailAddress, contentType: .username,
                                  error: state.emailError, appearance: .login)
                    AuthTextField(title: "비밀번호", placeholder: "비밀번호를 입력해 주세요", text: $state.password,
                                  isSecure: true, contentType: .password,
                                  error: state.passwordError, appearance: .login)
                        .onSubmit(submit)
                }
                .disabled(state.isSubmitting)

                Toggle("자동 로그인", isOn: $state.remembersLogin)
                    .appTextStyle(.caption)
                    .foregroundStyle(AppColors.Text.secondary)
                    .toggleStyle(AuthCheckboxToggleStyle())
                    .disabled(state.isSubmitting)
                    .accessibilityHint("선택하면 다음 앱 실행에서도 로그인을 유지합니다.")
                    .padding(.top, AppSpacing.item)
                    .padding(.bottom, AppSpacing.section)

                if state.onSubmit == nil { AuthMessage(text: "로그인 기능 연결 전이에요.").padding(.bottom, AppSpacing.content) }
                if let error = state.errorMessage {
                    AuthMessage(text: error).padding(.bottom, AppSpacing.content)
                }
                Button(action: submit) {
                    AuthSubmitLabel(title: "로그인", isLoading: state.isSubmitting)
                }
                .buttonStyle(AppButtonStyle())
                .disabled(state.isSubmitting || state.didSignIn || state.onSubmit == nil)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.item) {
                        signupLink
                        Text("|").foregroundStyle(AppColors.Text.secondary).accessibilityHidden(true)
                        passwordResetLink
                    }
                    VStack(spacing: AppSpacing.tight) { signupLink; passwordResetLink }
                }
                .appTextStyle(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)

                HStack(spacing: AppSpacing.item) {
                    Rectangle().fill(AppColors.secondary).frame(height: 1).accessibilityHidden(true)
                    Text("또는 다음으로 로그인")
                        .appTextStyle(.caption)
                        .foregroundStyle(AppColors.Text.secondary)
                        .layoutPriority(1)
                    Rectangle().fill(AppColors.secondary).frame(height: 1).accessibilityHidden(true)
                }
                .multilineTextAlignment(.center)
                .padding(.vertical, AppSpacing.item)

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        print("Apple로 로그인 요청 성공")
                        
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                              let tokenData = credential.identityToken,
                              let idToken = String(data: tokenData, encoding: .utf8) else {
                            print("Apple ID 토큰을 가져오지 못했어요.")
                            return
                        }
                        Task {
                            await viewModel.signInWithApple(idToken: idToken)
                        }
                    case .failure(let error):
                        if let appleError = error as? ASAuthorizationError, appleError.code == .canceled { return }
                        print("Apple로 로그인 요청 실패: ", error.localizedDescription)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .cornerRadius(14)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.surface.ignoresSafeArea())
        .foregroundStyle(AppColors.Text.primary)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityAction(.escape) { if let onBack { onBack() } else { dismiss() } }
        .onDisappear { state.onCancel?() }
    }

    private var signupLink: some View {
        Button(action: onSignup) {
            Text("회원가입").underline().frame(minHeight: AppMetrics.Control.minimumHitSize)
        }.disabled(state.isSubmitting)
    }

    private var passwordResetLink: some View {
        Button(action: onPasswordReset) {
            Text("비밀번호 찾기").underline().frame(minHeight: AppMetrics.Control.minimumHitSize)
        }.disabled(state.isSubmitting)
    }

    private func submit() {
        guard !state.isSubmitting else { return }
        state.onSubmit?()
    }
}

#Preview { NavigationStack { LoginView() } }
