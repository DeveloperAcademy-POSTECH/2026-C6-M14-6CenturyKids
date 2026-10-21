import SwiftUI

struct SignupConnectionConfirmationView: View {
    @Bindable var state: SignupScreenState
    var body: some View {
        SignupStepScreen(state: state, title: "소속 병원을\n확인했어요") {
            if let connection = state.connection {
                VStack(alignment: .leading, spacing: 20) {
                    AuthMessage(text: "코드 확인 완료", isError: false)
                    row("병원", connection.hospitalName)
                    if let department = connection.department { row("진료과", department) }
                    row("주치의", connection.doctorName)
                }
                .padding(AppSpacing.section).frame(maxWidth: .infinity, alignment: .leading)
                .appSurface(.authInformation)
            }
            Button { state.onAction?(.changeDoctorCode) } label: {
                Text("다른 코드 입력").underline().appTextStyle(.caption).frame(minHeight: AppMetrics.Control.minimumHitSize)
            }
        }
    }
    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).appTextStyle(.caption).foregroundStyle(AppColors.Text.secondary)
            Text(value).appTextStyle(.label)
        }
    }
}
