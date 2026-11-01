import SwiftUI

struct SignupView: View {
    let model: AuthFlowViewModel
    var body: some View { AuthFlowView(entry: .signup, model: model) }
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
            case .review: SignupReviewView(state: state, onLogin: onLogin)
            case .completion:
                SignupCompletionView(email: state.email) {
                    onLogin()
                }
            }
        }
        .onDisappear { state.onAction?(.cancel) }
    }

    private var roleSelection: some View {
        AuthFormScreen(title: "어떻게 방문하셨나요?", progress: state.step.progress, onBack: onBack, contentSpacing: 40) {
            VStack(spacing: AppLayout.Phone.columnSpacing) {
                roleCard(patient: true)
                roleCard(patient: false)
            }
            if state.hasAttemptedStep, let error = state.currentValidationError { AuthMessage(text: error) }
        } footer: {
            AppActions.Button("다음") { state.onAction?(.next) }.disabled(state.onAction == nil)
        }
    }

    private func roleCard(patient: Bool) -> some View {
        let selected = state.isPatient == patient
        return Button { state.isPatient = patient } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(patient ? "환자 및 보호자" : "의료진")
                    .appTypography(.caption)
                    .foregroundStyle(selected ? AppColors.Semantic.Text.action : AppColors.Semantic.Text.placeholder)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(selected ? AppColors.Semantic.Primary.default : AppColors.Semantic.Border.default, in: Capsule())
                Spacer(minLength: 16)
                VStack(alignment: .leading, spacing: 8) {
                    Text(patient ? "항암치료를 받고 있어요" : "환자를 진료하고 있어요")
                        .appTypography(.title)
                    Text(patient ? "증상을 기록하고 의사선생님과\n이야기 나누고 싶어요" : "기록된 증상을 확인하고\n진료에 활용하고 싶어요")
                        .appTypography(.caption)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, dynamicTypeSize.isAccessibilitySize ? 0 : 120)
                if dynamicTypeSize.isAccessibilitySize {
                    roleDoctor.frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 16)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
            .overlay(alignment: .bottomTrailing) {
                if !dynamicTypeSize.isAccessibilitySize { roleDoctor.padding(.trailing, 15) }
            }
            .foregroundStyle(AppColors.Semantic.Text.default)
            .background(selected ? AppColors.Semantic.Background.selected : AppColors.Semantic.Background.default)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 30)
                        .strokeBorder(AppColors.Semantic.Primary.default, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var roleDoctor: some View {
        // 원본 Figma PNG와 SHA256이 동일한 기존 그림을 재사용합니다.
        Image("CareCallHakro")
            .resizable().frame(width: 211.342, height: 211.342)
            .offset(x: -39.6, y: -3.96)
            .frame(width: 132, height: 132, alignment: .topLeading)
            .clipped().accessibilityHidden(true)
    }
}

#Preview { NavigationStack { SignupView(model: AuthFlowViewModel(session: AuthSessionState())) } }
