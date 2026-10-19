import SwiftUI

/// 로그인 이후 전달받은 환자 ID로 환자 화면의 의존성을 구성합니다.
@MainActor
struct PatientFlowCompositionView: View {
    @State private var settingsViewModel: SettingsViewModel

    init(container: DependencyContainer, patientId: UUID) {
        _settingsViewModel = State(
            initialValue: container.makeSettingsViewModel(patientId: patientId)
        )
    }

    var body: some View {
        PatientFlowView {
            SettingsFlowView(viewModel: settingsViewModel)
        }
    }
}
