import SwiftUI

/// 인증에서 확인한 환자 ID로 환자 화면의 의존성만 구성합니다.
@MainActor
struct PatientFlowCompositionView: View {
    @State private var homeViewModel: HomeViewModel
    @State private var painViewModel: PainRecordViewModel
    @State private var settingsViewModel: SettingsViewModel
    @State private var notificationSettingsViewModel: NotificationSettingsViewModel
    @State private var recordDetailViewModel: RecordDetailViewModel
    @State private var recordsViewModel: RecordsViewModel
    @State private var previsitLetterViewModel = PrevisitLetterViewModel()
    private let container: DependencyContainer
    private let patientId: UUID

    init(container: DependencyContainer, patientId: UUID, authSession: AuthSessionState) {
        self.container = container
        self.patientId = patientId
        _homeViewModel = State(initialValue: HomeViewModel(
            patientID: patientId,
            repositories: .init(patients: container.patientRepository, doctors: container.doctorRepository)
        ))
        _painViewModel = State(
            initialValue: container.makePainRecordViewModel()
        )
        _settingsViewModel = State(
            initialValue: container.makeSettingsViewModel(patientId: patientId, authSession: authSession)
        )
        _notificationSettingsViewModel = State(
            initialValue: container.makeNotificationSettingsViewModel()
        )
        let recordDetailViewModel = container.makeRecordDetailViewModel(patientId: patientId)
        _recordDetailViewModel = State(initialValue: recordDetailViewModel)
        _recordsViewModel = State(
            initialValue: container.makeRecordsViewModel(patientId: patientId, detail: recordDetailViewModel)
        )
    }

    var body: some View {
        PatientFlowView(
            home: homeViewModel.state,
            onHomeContextChange: { visible, active in
                homeViewModel.updateContext(.init(patientID: patientId, isVisible: visible, isAppActive: active))
            },
            onReloadHome: { homeViewModel.reload() },
            previsit: { session in
                PrevisitFlowView(doctorName: homeViewModel.state.doctorName ?? "선생님", session: session,
                                 letter: previsitLetterViewModel) {
                    async let pain = container.painRepository.findByPatientId(patientId)
                    async let symptoms = container.symptomRepository.findByPatientId(patientId)
                    let records = try await (pain, symptoms)
                    try Task.checkCancellation()
                    return try PrevisitRecordedDays.make(pain: records.0, symptoms: records.1, patientID: patientId,
                                                        calendar: RecordDetailViewModel.calendar)
                }
            },
            pain: { navigation in
                PainRecordView(viewModel: painViewModel, onShowRecord: navigation.showRecord)
            },
            preparePainDetail: { date in
                recordDetailViewModel.pain.period = .day
                recordDetailViewModel.show(.pain, at: date)
            },
            painDetail: {
                PainRecordDetailView(state: recordDetailViewModel.pain)
            },
            careCall: { navigation in
                CareCallFlowView(
                  makeViewModel: container.makeCareCallViewModel,
                  autoStartVoice: navigation.autoStartVoice,
                  onShowRecord: navigation.showRecord,
                  onHome: navigation.home
                )
            },
            prepareSymptomDetail: { date in
                recordDetailViewModel.symptom.period = .day
                recordDetailViewModel.show(.symptom, at: date)
            },
            symptomDetail: { SymptomRecordDetailView(state: recordDetailViewModel.symptom) },
            records: {
                RecordsFlowView(state: recordsViewModel.state,
                                pain:{ PainRecordDetailView(state: recordDetailViewModel.pain) },
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
