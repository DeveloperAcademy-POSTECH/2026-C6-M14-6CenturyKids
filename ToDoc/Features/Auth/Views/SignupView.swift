import SwiftUI

struct SignupView: View {
    @State private var flow: AuthFlowModel

    init(model: SignupViewModel? = nil, onLogin: (() -> Void)? = nil,
         loginModel: LoginViewModel? = nil,
         resetPassword: @escaping PasswordResetViewModel.ResetPassword = { _ in throw AuthPresentationError.unavailable },
         onSignedIn: @escaping () -> Void = {}) {
        _flow = State(initialValue: AuthFlowModel(entry: .signup, login: loginModel, signup: model,
            passwordReset: PasswordResetViewModel(resetPassword: resetPassword),
            onLogin: onLogin, onSignedIn: onSignedIn))
    }

    init(flow: AuthFlowModel) { _flow = State(initialValue: flow) }
    var body: some View { AuthFlowView(flow: flow) }
}

struct SignupFormView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: SignupViewModel
    let onBack: () -> Void
    let onLogin: () -> Void

    var body: some View {
        Group {
            switch model.step {
            case .role: roleSelection
            case .name: SignupNameView(model: model)
            case .email: SignupEmailView(model: model)
            case .password: SignupPasswordView(model: model)
            case .passwordConfirmation: SignupPasswordConfirmationView(model: model)
            case .terms: SignupTermsView(model: model)
            case .doctorCode: SignupDoctorCodeView(model: model)
            case .doctorConfirmation: SignupConnectionConfirmationView(model: model)
            case .patientInfo: SignupPatientInfoView(model: model)
            case .cancerType: SignupCancerTypeView(model: model)
            case .cancerStage: SignupCancerStageView(model: model)
            case .review: SignupReviewView(model: model)
            case .completion:
                SignupCompletionView(email: AuthFormValidation.trimmed(model.email)) {
                    onLogin()
                }
            }
        }
        .onDisappear { model.cancel() }
    }

    private var roleSelection: some View {
        AuthFormScreen(title: "어떻게\n이용하시나요?", progress: model.step.progress, onBack: onBack) {
            VStack(spacing: 16) {
                roleCard(patient: true)
                roleCard(patient: false)
            }
            if model.hasAttemptedStep, let error = model.currentValidationError { AuthMessage(text: error) }
        } footer: {
            Button("다음") { model.next() }.buttonStyle(AppButtonStyle())
        }
    }

    private func roleCard(patient: Bool) -> some View {
        let selected = model.isPatient == patient
        return Button { model.isPatient = patient } label: {
            HStack(alignment: .bottom, spacing: 4) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(patient ? "환자로\n이용할게요" : "의사로\n이용할게요").appTextStyle(.heading)
                    Text(patient ? "iPhone에서\n기록해요" : "iPad에서\n확인해요")
                        .appTextStyle(.caption).foregroundStyle(AppColors.Text.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 24).padding(.leading, 24)
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(patient ? "Auth/Patient" : "Auth/Doctor")
                        .resizable().frame(width: 254, height: 254)
                        .offset(x: -58)
                        .frame(width: 135, height: 167, alignment: .topLeading)
                        .clipped().accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
            .background(selected ? AppColors.primary : AppColors.secondary, in: RoundedRectangle(cornerRadius: 24))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(alignment: .topTrailing) {
                if selected { Image(systemName: "checkmark.circle.fill").padding(16) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview { NavigationStack { SignupView() } }
