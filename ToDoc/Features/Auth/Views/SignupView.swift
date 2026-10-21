import SwiftUI

struct SignupView: View {
    var body: some View { AuthFlowView(entry: .signup) }
}

struct SignupFormView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let state: SignupScreenState
    let onBack: () -> Void
    let onLogin: () -> Void
    var onRestart: (() -> Void)?

    var body: some View {
        Group {
            switch state.step {
            case .role: roleSelection
            case .name: SignupNameView(state: state)
            case .email: SignupEmailView(state: state)
            case .password: SignupPasswordView(state: state)
            case .passwordConfirmation: SignupPasswordConfirmationView(state: state)
            case .terms: SignupTermsView(state: state, onLogin: onLogin, onRestart: onRestart)
            case .patientInfo: SignupPatientInfoView(state: state)
            case .cancerType: SignupCancerTypeView(state: state)
            case .cancerStage: SignupCancerStageView(state: state)
            case .doctorCode: SignupDoctorCodeView(state: state)
            case .doctorConfirmation: SignupConnectionConfirmationView(state: state)
            case .review: SignupReviewView(state: state, onLogin: onLogin, onRestart: onRestart)
            case .completion:
                SignupCompletionView(email: state.email) {
                    onLogin()
                }
            }
        }
        .onDisappear { state.onAction?(.cancel) }
    }

    private var roleSelection: some View {
        AuthFormScreen(title: "어떻게\n이용하시나요?", progress: state.step.progress, onBack: onBack) {
            VStack(spacing: AppSpacing.content) {
                roleCard(patient: true)
                roleCard(patient: false)
            }
            if state.hasAttemptedStep, let error = state.currentValidationError { AuthMessage(text: error) }
        } footer: {
            Button("다음") { state.onAction?(.next) }.buttonStyle(AppButtonStyle()).disabled(state.onAction == nil)
        }
    }

    private func roleCard(patient: Bool) -> some View {
        let selected = state.isPatient == patient
        return Button { state.isPatient = patient } label: {
            HStack(alignment: .bottom, spacing: AppSpacing.tight) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(patient ? "환자로\n이용할게요" : "의사로\n이용할게요").appTextStyle(.heading)
                    Text(patient ? "iPhone에서\n기록해요" : "iPad에서\n확인해요")
                        .appTextStyle(.caption).foregroundStyle(AppColors.Text.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, AppSpacing.section).padding(.leading, AppSpacing.section)
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
            .appSurface(.authRole(isSelected: selected))
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.Auth.roleRadius))
            .overlay(alignment: .topTrailing) {
                if selected { Image(systemName: "checkmark.circle.fill").padding(AppSpacing.content).accessibilityHidden(true) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview { NavigationStack { SignupView() } }
