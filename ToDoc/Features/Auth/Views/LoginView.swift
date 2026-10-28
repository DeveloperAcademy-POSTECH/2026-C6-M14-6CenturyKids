import SwiftUI

struct LoginView: View {
    var body: some View { AuthFlowView() }
}

struct LoginFormView: View {
    @Environment(\.dismiss) private var dismiss
    let state: LoginScreenState
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

                Button {} label: {
                    Label("Apple로 로그인", systemImage: "apple.logo")
                        .appTextStyle(.caption)
                        .frame(maxWidth: .infinity, minHeight: AppMetrics.Auth.alternateSignInMinimumHeight)
                        .appSurface(.authAlternateSignIn)
                }
                .buttonStyle(.plain)
                .disabled(true)
                .accessibilityHint("Apple 로그인은 준비 중입니다.")
                .padding(.top, 20)
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
