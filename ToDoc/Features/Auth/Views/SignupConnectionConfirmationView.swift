import SwiftUI

struct SignupConnectionConfirmationView: View {
    @Bindable var model: SignupViewModel
    var body: some View {
        SignupStepScreen(model: model, title: "소속 병원을\n확인했어요") {
            if let connection = model.connection {
                VStack(alignment: .leading, spacing: 20) {
                    AuthMessage(text: "인증 완료", isError: false)
                    row("병원", connection.hospitalName)
                    if let department = connection.department { row("진료과", department) }
                    row("주치의", connection.doctorName)
                }
                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.secondary, in: RoundedRectangle(cornerRadius: 20))
            }
            Button { model.changeDoctorCode() } label: {
                Text("다른 코드 입력").underline()
            }
            .appTextStyle(.caption).frame(minHeight: 44)
        }
    }
    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).appTextStyle(.caption).foregroundStyle(AppColors.Text.secondary)
            Text(value).appTextStyle(.label)
        }
    }
}
