import CoreLocation
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
    @State private var notificationViewModel: NotificationViewModel
    @Environment(AppRouter.self) private var router
    @State private var previsitLetterViewModel: PrevisitLetterViewModel
    @State private var demoAdmin: DemoAdminService
    private let container: DependencyContainer
    private let patientId: UUID

    init(container: DependencyContainer, patientId: UUID) {
        self.container = container
        self.patientId = patientId
        _previsitLetterViewModel = State(initialValue: PrevisitLetterViewModel(
            patientID: patientId, calendar: RecordDetailViewModel.calendar,
            load: { try await container.previsitRepository.findByPatientId(patientId) },
            save: { try await container.previsitRepository.save(entity: $0) },
            loadDay: { date in
                let calendar = RecordDetailViewModel.calendar
                guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else {
                    throw DateConversionError.dayAddingError
                }
                async let pain = container.painRepository.findByPatientIdAndDate(
                    patientId: patientId, from: date, to: date)
                async let symptoms = container.symptomRepository.findByPatientIdAndDate(
                    patientId: patientId, from: date, to: end)
                return try await PrevisitRecordedDays.make(pain: pain, symptoms: symptoms,
                                                           patientID: patientId, calendar: calendar).first
            }
        ))
        _demoAdmin = State(initialValue: DemoAdminService(
            patientId: patientId, pain: container.painRepository, symptoms: container.symptomRepository,
            previsits: container.previsitRepository, pendingCalls: FilePendingCareCallRepository(),
            schedulePainAfterReminder: LocalNotificationAdapter.schedulePainAfterReminder(at:)
        ))
        _homeViewModel = State(initialValue: HomeViewModel(
            patientID: patientId,
            repositories: .init(patients: container.patientRepository, doctors: container.doctorRepository,
                                notifications: container.notificationRepository)
        ))
        _painViewModel = State(
            initialValue: container.makePainRecordViewModel()
        )
        _settingsViewModel = State(
            initialValue: container.makeSettingsViewModel(patientId: patientId)
        )
        _notificationSettingsViewModel = State(
            initialValue: container.makeNotificationSettingsViewModel(
                userId: patientId
            )
        )
        let recordDetailViewModel = container.makeRecordDetailViewModel(patientId: patientId)
        _recordDetailViewModel = State(initialValue: recordDetailViewModel)
        _recordsViewModel = State(
            initialValue: container.makeRecordsViewModel(patientId: patientId, detail: recordDetailViewModel)
        )
        _notificationViewModel = State(initialValue: container.makeNotificationViewModel(patientId: patientId))
    }

    var body: some View {
        PatientFlowView(
            home: homeViewModel.state,
            onHomeContextChange: { visible, active in
                homeViewModel.updateContext(.init(patientID: patientId, isVisible: visible, isAppActive: active))
            },
            onReloadHome: { homeViewModel.reload() },
            previsit: { session in
                PrevisitFlowView(doctorName: homeViewModel.state.doctorName ?? "선생님",
                                 patientName: homeViewModel.state.patientName ?? "", session: session,
                                 letter: previsitLetterViewModel) {
                    let now = Date.now
                    let calendar = RecordDetailViewModel.calendar
                    guard let range = PrevisitRecordedDays.selectionRange(now: now, calendar: calendar) else {
                        throw DateConversionError.dayAddingError
                    }
                    // 통증 저장소는 종료일 포함, 증상 저장소는 종료일 미포함입니다.
                    async let pain = container.painRepository.findByPatientIdAndDate(
                        patientId: patientId, from: range.start, to: calendar.startOfDay(for: now))
                    async let symptoms = container.symptomRepository.findByPatientIdAndDate(
                        patientId: patientId, from: range.start, to: range.end)
                    let records = try await (pain, symptoms)
                    try Task.checkCancellation()
                    let days = try PrevisitRecordedDays.make(pain: records.0, symptoms: records.1, patientID: patientId,
                                                            calendar: RecordDetailViewModel.calendar)
                    return PrevisitRecordedDays.selectableDays(days, now: now, calendar: calendar)
                }
            },
            previsitLetters: previsitLetterViewModel,
            trackPrevisitAnalytics: container.analytics.track,
            pain: { navigation in
                PainRecordView(viewModel: painViewModel, analytics: container.analytics,
                               entrySource: "home", onShowRecord: navigation.showRecord)
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
            notifications: { NotificationView(state: notificationViewModel.state) },
            records: {
                RecordsFlowView(state: recordsViewModel.state,
                                pain:{ PainRecordDetailView(state: recordDetailViewModel.pain) },
                                symptom: { SymptomRecordDetailView(state: recordDetailViewModel.symptom) })
            },
            settings: {
                SettingsFlowView(
                    viewModel: settingsViewModel,
                    withdrawal: {
                        AccountWithdrawalView(
                            viewModel: container.makeAccountWithdrawalViewModel()
                        )
                    },
                    notifications: {
                        NotificationSettingsView(viewModel: notificationSettingsViewModel)
                    }
                )
            }
        )
        .environment(demoAdmin)
        .task(id: patientId) { await startArrivalNotifications() }
        .task {
            // 관리자 기능으로 기록을 바꾸면 통증·진료 전·홈이 다시 불러온다
            demoAdmin.onChanged = {
                await painViewModel.load()
                await loadPrevisitLetters()
                homeViewModel.reload()
            }
        }
        .task(id: homeViewModel.state.doctorName) { await loadPrevisitLetters() }
    }

    private func loadPrevisitLetters() async {
        // 선택한 날짜의 통증·증상을 기존 기록과 동일한 표현으로 복원합니다.
        let days: [PrevisitDay]
        do {
            async let pain = container.painRepository.findByPatientId(patientId)
            async let symptoms = container.symptomRepository.findByPatientId(patientId)
            days = try await PrevisitRecordedDays.make(pain: pain, symptoms: symptoms, patientID: patientId,
                                                      calendar: RecordDetailViewModel.calendar)
        } catch {
            days = []
        }
        await previsitLetterViewModel.load(days: days, doctorName: homeViewModel.state.doctorName ?? "선생님")
    }

    /// 온보딩·로그인을 마치고 환자 화면에 들어오면 위치 권한을 묻고, 허용한 만큼 병원 도착을 감시합니다.
    private func startArrivalNotifications() async {
        let arrival = container.hospitalArrivalService
        let permission = container.locationPermission
        let patientId = patientId
        let homeViewModel = homeViewModel
        let router = router
        arrival.onSaved = { homeViewModel.refreshUnreadBadge() }
        notificationViewModel.onOpen = { type in
            guard type == .previsitReminder else { return }
            router.handle(.previsit)
        }
        permission.onChange = { status in
            Task { await arrival.update(patientId: patientId, authorized: status.allowsArrival) }
        }
        permission.requestIfNeeded()
        await arrival.update(patientId: patientId, authorized: permission.status.allowsArrival)
    }
}

private extension CLAuthorizationStatus {
    /// 앱을 사용하는 동안만 허용이어도 감시한다 (iOS가 앱을 보고 있을 때만 알려 준다)
    var allowsArrival: Bool { self == .authorizedAlways || self == .authorizedWhenInUse }
}
