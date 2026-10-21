import SwiftUI

/// 인증에서 확인한 환자 ID로 환자 화면의 의존성만 구성합니다.
@MainActor
struct PatientFlowCompositionView: View {
    @State private var painViewModel: PainRecordViewModel
    @State private var settingsViewModel: SettingsViewModel
    @State private var notificationSettingsViewModel: NotificationSettingsViewModel
    @State private var recordDetailViewModel: RecordDetailViewModel
    private let container: DependencyContainer

    init(container: DependencyContainer, patientId: UUID) {
        self.container = container
        _painViewModel = State(
            initialValue: container.makePainRecordViewModel()
        )
        _settingsViewModel = State(
            initialValue: container.makeSettingsViewModel(patientId: patientId)
        )
        _notificationSettingsViewModel = State(
            initialValue: container.makeNotificationSettingsViewModel()
        )
        _recordDetailViewModel = State(
            initialValue: container.makeRecordDetailViewModel(patientId: patientId)
        )
    }

    var body: some View {
        PatientFlowView(
            pain: { PainRecordView(viewModel: painViewModel) },
            careCall: { CareCallFlowView(makeViewModel: container.makeCareCallViewModel) },
            records: {
                RecordsFlowView(pain: { PainRecordDetailView(state: recordDetailViewModel.pain) },
                                symptom: { SymptomRecordDetailView(state: recordDetailViewModel.symptom) })
            },
            settings: {
                SettingsFlowView(
                    viewModel: settingsViewModel,
                    notifications: {
                        NotificationSettingsView(viewModel: notificationSettingsViewModel)
                    }
                )
            }
        )
    }
}
