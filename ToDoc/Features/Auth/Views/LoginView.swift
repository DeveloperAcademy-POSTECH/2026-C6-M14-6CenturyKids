import AuthenticationServices
import SwiftUI

struct LoginView: View {
    let model: AuthFlowViewModel
    var body: some View { AuthFlowView(model: model) }
}

struct LoginFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputDismissal = 0
    @State private var isKeyboardVisible = false
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isPasswordFocused: Bool
    @ScaledMetric(relativeTo: .body) private var separatorFontSize: CGFloat = 16
    let viewModel: LoginViewModel

    private var state: LoginScreenState {
        viewModel.state
    }

    let onSignup: () -> Void
    let onPasswordReset: () -> Void
    var onBack: (() -> Void)? = nil

    var body: some View {
        @Bindable var state = state
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Image("SodakLogo")
                        .resizable().scaledToFit()
                        .frame(width: 49, height: 24.126)
                        .accessibilityLabel("속닥")
                        .padding(.bottom, 13.874)
                    Text("만나서 반가워요")
                        .appTypography(.titleLarge)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 84)
                    VStack(alignment: .leading, spacing: 10) {
                        AuthTextField(title: "이메일", placeholder: "이메일", text: $state.email,
                                      keyboard: .emailAddress, contentType: .username,
                                      error: state.emailError, appearance: .login, focus: $isEmailFocused)
                            .submitLabel(.next)
                            .onSubmit {
                                isEmailFocused = false
                                isPasswordFocused = true
                            }
                        AuthTextField(title: "비밀번호", placeholder: "비밀번호", text: $state.password,
                                      isSecure: true, contentType: .password,
                                      error: state.passwordError, appearance: .login, focus: $isPasswordFocused)
                            .submitLabel(.go)
                            .onSubmit(submit)
                    }
                    .disabled(state.isSubmitting)
                    if state.onSubmit == nil { AuthMessage(text: "로그인 기능 연결 전이에요.").padding(.top, 14) }
                    if let error = state.errorMessage { AuthMessage(text: error).padding(.top, 14) }
                    if !isKeyboardVisible {
                        accountLinks
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 4)
                        loginActions.padding(.top, 30)
                    }
                }
                .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                .padding(.top, max(44, 182 - geometry.safeAreaInsets.top))
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .topLeading) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, AppLayout.Phone.horizontalMargin)
                    .accessibilityLabel("온보딩으로 돌아가기")
                }
            }
        }
        .environment(\.authInputDismissal, inputDismissal)
        .background(AppColors.Semantic.Background.surface.ignoresSafeArea())
        .foregroundStyle(AppColors.Semantic.Text.default)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityAction(.escape) { if let onBack { onBack() } else { dismiss() } }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            isKeyboardVisible = frame.height > 0
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onDisappear { isKeyboardVisible = false; state.onCancel?() }
    }

    private var loginActions: some View {
        VStack(spacing: 0) {
            Button(action: submit) {
                AuthSubmitLabel(title: "로그인", isLoading: state.isSubmitting)
            }
            .buttonStyle(LoginActionButtonStyle())
            .accessibilityValue(state.isSubmitting ? "처리 중" : "")
            .disabled(state.isSubmitting || state.didSignIn || state.onSubmit == nil)
            HStack(spacing: 12) {
                Rectangle().fill(Color(red: 222.0 / 255, green: 227.0 / 255, blue: 219.0 / 255)).frame(height: 1)
                Text("또는 다음으로 로그인")
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .layoutPriority(1)
                Rectangle().fill(Color(red: 222.0 / 255, green: 227.0 / 255, blue: 219.0 / 255)).frame(height: 1)
            }
            .font(Font(AppTypography.font(for: .captionRegular, size: separatorFontSize)))
            .foregroundStyle(Color(white: 74.0 / 255))
            .frame(minHeight: 24)
            .padding(.top, 100)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
                do {
                    request.nonce = try viewModel.prepareAppleSignIn()
                } catch {
                    state.errorMessage = (error as? AuthFlowError)?.message ?? "Apple 로그인 요청을 준비하지 못했어요."
                }
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let tokenData = credential.identityToken,
                          let idToken = String(data: tokenData, encoding: .utf8) else {
                        viewModel.cancelAppleSignIn()
                        state.errorMessage = "Apple ID 토큰을 가져오지 못했어요. 다시 시도해 주세요."
                        return
                    }
                    Task {
                        await viewModel.signInWithApple(idToken: idToken)
                    }
                case .failure(let error):
                    viewModel.cancelAppleSignIn()
                    if let appleError = error as? ASAuthorizationError, appleError.code == .canceled { return }
                    state.errorMessage = "Apple 로그인에 실패했어요. 다시 시도해 주세요."
                }
            }
            .disabled(state.isSubmitting || state.didSignIn)
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .cornerRadius(14)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(white: 77.0 / 255), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .padding(.top, 22)
        }
    }

    private var accountLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                signupLink
                Rectangle().fill(AppColors.Semantic.Border.default)
                    .frame(width: 1, height: 14).accessibilityHidden(true)
                passwordResetLink
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 0) {
                signupLink
                passwordResetLink
            }
        }
        .foregroundStyle(AppColors.Semantic.Text.sub)
    }

    private var signupLink: some View {
        Button(action: onSignup) {
            Text("회원가입").appTypography(.label)
                .frame(minHeight: AppMetrics.Control.minimumHitSize)
        }.buttonStyle(.plain).disabled(state.isSubmitting)
    }

    private var passwordResetLink: some View {
        Button(action: onPasswordReset) {
            Text("비밀번호 찾기").appTypography(.label)
                .frame(minHeight: AppMetrics.Control.minimumHitSize)
        }.buttonStyle(.plain).disabled(state.isSubmitting)
    }

    private func submit() {
        guard !state.isSubmitting else { return }
        inputDismissal &+= 1
        state.onSubmit?()
    }
}

/// 최신 로그인 시안의 54pt 액션. 공용 Actions의 80pt 규격은 그대로 유지합니다.
private struct LoginActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appTypography(.labelLarge)
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? AppColors.Semantic.Text.onPrimary : AppColors.Semantic.Text.onPrimaryDisabled)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isEnabled
                        ? (configuration.isPressed ? AppColors.Semantic.Primary.pressed : AppColors.Semantic.Primary.default)
                        : AppColors.Semantic.Primary.disabled,
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(AppGradients.primaryBorder, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview { NavigationStack { LoginView(model: AuthFlowViewModel(session: AuthSessionState())) } }
