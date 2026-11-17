//
//  DependencyContainer.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation
import os

@MainActor
final class DependencyContainer {
    let analytics: AmplitudeAnalytics
    /// 로그인·설정·탈퇴가 함께 사용하는 앱 수명의 인증 상태입니다.
    let authSession: AuthSessionState
    let localStore: LocalFileStore
    let authRepository: any AuthRepository
    let userRepository: any UserRepository
    let hospitalRepository: any HospitalRepository
    let doctorRepository: any DoctorRepository
    let patientRepository: any PatientRepository
    let symptomRepository: any SymptomRepository
    let previsitRepository: any PrevisitRepository
    let painRepository: any PainRepository
    let deviceTokenRepository: any DeviceTokenRepository
    /// 앱 알림 목록은 서버 없이 폰에만 남긴다
    let notificationRepository: any NotificationRepository
    let notificationSettingsRepository: any NotificationSettingsRepository
    let careCallReminderScheduler: CareCallReminderScheduler
    
    let liveActivityService: LiveActivityService
    let locationPermission: LocationPermissionRequester
    let hospitalArrivalService: HospitalArrivalService
    
    init(analytics: AmplitudeAnalytics) {
        self.analytics = analytics
        authSession = AuthSessionState(loginPreference: AuthLoginPreference(defaults: .standard))
        let store = LocalFileStore()
        localStore = store
        authRepository = LocalAuthRepository()
        userRepository = LocalUserRepository(store: store)
        hospitalRepository = OfflineHospitalRepository()
        doctorRepository = OfflineDoctorRepository()
        patientRepository = LocalPatientRepository(store: store)
        symptomRepository = LocalSymptomRepository(store: store)
        previsitRepository = LocalPrevisitRepository(store: store)
        painRepository = LocalPainRepository(store: store)
        deviceTokenRepository = OfflineDeviceTokenRepository()
        notificationRepository = FileNotificationRepository()
        let notificationSettings = LocalNotificationSettingsRepository(store: store)
        notificationSettingsRepository = notificationSettings
        careCallReminderScheduler = CareCallReminderScheduler(repository: notificationSettings, userId: OfflineProfile.id)

        self.liveActivityService = LiveActivityService(tokenRepository: deviceTokenRepository, authRepository: authRepository)
        locationPermission = LocationPermissionRequester()
        hospitalArrivalService = HospitalArrivalService(
            notifications: notificationRepository,
            patients: patientRepository, doctors: doctorRepository, hospitals: hospitalRepository
        )
    }

    func makePainRecordViewModel() -> PainRecordViewModel {
        PainRecordViewModel(
            authRepository: authRepository,
            patientRepository: patientRepository,
            painRepository: painRepository,
            scheduleAfterReminder: LocalNotificationAdapter.schedulePainAfterReminder(at:),
            cancelAfterReminder: LocalNotificationAdapter.cancelPainAfterReminder,
            checkRemindersAllowed: LocalNotificationAdapter.isPainReminderAllowed,
            startLiveActivity: LiveActivityService.startPainLiveActivity(for:followUpAt:),
            endLiveActivity: LiveActivityService.endPainLiveActivity(recordID:)
        )
    }

    @MainActor
    func makeSettingsViewModel(patientId: UUID) -> SettingsViewModel {
        SettingsViewModel(
            patientId: patientId,
            authRepository: authRepository,
            authSession: authSession,
            userRepository: userRepository,
            patientRepository: patientRepository,
            doctorRepository: doctorRepository,
            hospitalRepository: hospitalRepository
        )
    }

    @MainActor
    func makeNotificationSettingsViewModel(
        userId: UUID
    ) -> NotificationSettingsViewModel {
        NotificationSettingsViewModel(
            userId: userId,
            notificationSettingsRepository: notificationSettingsRepository,
            synchronizeReminders: careCallReminderScheduler.synchronize
        )
    }

    @MainActor
    func makeNotificationViewModel(patientId: UUID) -> NotificationViewModel {
        NotificationViewModel(patientId: patientId, repository: notificationRepository)
    }

    @MainActor
    func makeRecordDetailViewModel(patientId: UUID) -> RecordDetailViewModel {
        RecordDetailViewModel(
            patientId: patientId,
            painRepository: painRepository,
            symptomRepository: symptomRepository
        )
    }

    @MainActor
    func makeRecordsViewModel(patientId: UUID, detail: RecordDetailViewModel) -> RecordsViewModel {
        RecordsViewModel(
            patientId: patientId,
            painRepository: painRepository,
            symptomRepository: symptomRepository,
            detail: detail
        )
    }

    /// 인증과 가입에 필요한 저장소는 컨테이너가 연결합니다.
    @MainActor func makeAuthFlow() -> AuthFlowViewModel {
        AuthFlowViewModel(
            repositories: .init(auth: authRepository, users: userRepository, patients: patientRepository,
                                doctors: doctorRepository, hospitals: hospitalRepository),
            configuration: AuthConfiguration(),
            session: authSession
        )
    }

    /// 케어콜 서비스 (설정 파일·마이크·음성 인식·음성 합성·AI 모델). 부를 때마다 새로 만들고 컨테이너는 들고 있지 않는다.
    /// AI 모델은 대기 화면의 준비 단계(loadModel)에서 확인한다
    /// custom: 마이크 대신 쓸 소리 입력 (시연·측정용 자동 환자). 없으면 실제 마이크
    func makeCareCallService(recorder custom: AudioRecorder? = nil) throws -> CareCallService {
        let recorder = custom ?? AVAudioEngineAdapter()
        let config = try Bundle.main.decodeJSON(CareCallConfig.self, named: "side_effects")
        let bodyParts = try Bundle.main.decodeJSON(BodyPartDictionary.self, named: "body_parts")
        return CareCallService(
            config: config,
            rules: try Bundle.main.decodeJSON(EmergencyRules.self, named: "emergency_rules"),
            bodyParts: bodyParts,
            recorder: recorder,
            recognizer: SpeechAnalyzerAdapter(recorder: recorder),
            // 의사 선생님 녹음으로 읽고, 녹음이 없는 문장은 기기 음성으로 읽는다
            voice: DoctorVoiceSynthesizer(clips: try Bundle.main.decodeJSON(DoctorVoiceClips.self, named: "doctor_voice"),
                                          fallback: AVSpeechSynthesizerAdapter()),
            loadAnalyzer: {
                let fallback = OfflineCareCallAnalyzer(config: config, bodyParts: bodyParts)
                // SystemLanguageModel.default runs on this device. Never request
                // a model download or a cloud model while preparing the booth app.
                let primary = try? FoundationModelsCareCallAdapter(model: LanguageModelProvider.systemModel())
                FoundationModelsCareCallAdapter.timingLog.notice("증상 분석 준비: \(primary == nil ? "오프라인 규칙 (FM 사용 불가)" : "온디바이스 FM 우선", privacy: .public)")
                return FallbackCareCallAnalyzer(primary: primary, fallback: fallback)
            }
        )
    }

    /// 케어콜 화면에 들어갈 때마다 새로 만든다 (서비스와 같은 이유). 로그인 환자는 ViewModel이 찾는다
    @MainActor
    func makeCareCallViewModel() throws -> CareCallViewModel {
        let model = CareCallViewModel(
            service: try makeCareCallService(),
            repository: symptomRepository,
            pending: FilePendingCareCallRepository(),
            authRepository: authRepository,
            patientRepository: patientRepository,
            trackAnalytics: analytics.track
        )
        model.preservesPartialFollowUps = true
        return model
    }

    @MainActor
    func makeAccountWithdrawalViewModel() -> AccountWithdrawalViewModel {
        AccountWithdrawalViewModel(authRepository: authRepository, authSession: authSession)
    }

}
