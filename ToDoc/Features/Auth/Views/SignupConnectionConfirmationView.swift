import SwiftUI

struct SignupConnectionConfirmationView: View {
    @Bindable var state: SignupScreenState

    var body: some View {
        AuthFormScreen(title: "소속 병원을 확인했어요", progress: state.step.progress,
                       onBack: { state.onAction?(.back) }, subtitle: "병원에서 받은 인증 코드예요",
                       contentSpacing: 85) {
            if let connection = state.connection {
                VStack(spacing: 24) {
                    doctorPortrait
                    VStack(spacing: 4) {
                        Text(connection.hospitalName).appTypography(.labelLarge)
                        Text("\(connection.doctorName) 선생님").appTypography(.titleLarge)
                        if let department = connection.department {
                            Text(department).appTypography(.label)
                                .foregroundStyle(AppColors.Semantic.Text.disabled)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
            if state.hasAttemptedStep, let error = state.currentValidationError { AuthMessage(text: error) }
        } footer: {
            VStack(spacing: 3) {
                Button { state.onAction?(.changeDoctorCode) } label: {
                    Text("코드 재입력").underline().appTypography(.bodySmall)
                        .foregroundStyle(AppColors.Semantic.Text.sub)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(state.isWorking || state.isAccountLocked)
                AppActions.Button("다음") { state.onAction?(.next) }
                    .disabled(state.isWorking || state.onAction == nil)
            }
        }
    }

    private var doctorPortrait: some View {
        ZStack(alignment: .topLeading) {
            Image("Auth/ConnectionBackground").resizable().frame(width: 120, height: 120)
            // Figma 원본과 같은 PNG이며 원형 안의 원본 위치를 유지합니다.
            Image("CareCallHakro").resizable().frame(width: 160.108, height: 160.108)
                .offset(x: -20.054, y: 9.057)
            Image("Auth/ConnectionBorder").resizable().frame(width: 120, height: 120)
        }
        .frame(width: 120, height: 120, alignment: .topLeading)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
