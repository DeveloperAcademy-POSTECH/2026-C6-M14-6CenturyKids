//
//  DependencyContainer.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation

final class DependencyContainer {
    let supabaseProvider: SupabaseClientProvider
    let authRepository: any AuthRepository
    let userRepository: any UserRepository
    let hospitalRepository: any HospitalRepository
    let doctorRepository: any DoctorRepository
    let patientRepository: any PatientRepository
    let symptomRepository: any SymptomRepository
    let painRepository: any PainRepository
    let deviceTokenRepository: any DeviceTokenRepository
    
    let liveActivityService: LiveActivityService
    
    init(configuration: SupabaseConfiguration) {
        let provider = SupabaseClientProvider(
            configuration: configuration
        )

        supabaseProvider = provider
        let client = provider.client
        authRepository = SupabaseAuthRepository(client: client)
        userRepository = SupabaseUserRepository(client: client)
        hospitalRepository = SupabaseHospitalRepository(client: client)
        doctorRepository = SupabaseDoctorRepository(client: client)
        patientRepository = SupabasePatientRepository(client: client)
        symptomRepository = SupabaseSymptomRepository(client: client)
        painRepository = SupabasePainRepository(client: client)
        deviceTokenRepository = SupabaseDeviceTokenRepository(client: client)
        
        self.liveActivityService = LiveActivityService(tokenRepository: deviceTokenRepository, authRepository: authRepository)
    }

    func makePainRecordViewModel() -> PainRecordViewModel {
        PainRecordViewModel(
            authRepository: authRepository,
            patientRepository: patientRepository,
            painRepository: painRepository
        )
    }

    @MainActor
    func makeSettingsViewModel(patientId: UUID) -> SettingsViewModel {
        SettingsViewModel(
            patientId: patientId,
            userRepository: userRepository,
            patientRepository: patientRepository,
            doctorRepository: doctorRepository,
            hospitalRepository: hospitalRepository
        )
    }

    /// 인증과 가입에 필요한 실제 저장소를 연결하고, 전달된 저장소가 있으면 우선 사용합니다.
    @MainActor func makeAuthFlow(configuration: AuthConfiguration = .init(),
                      users: (any UserRepository)? = nil,
                      patients: (any PatientRepository)? = nil,
                      doctors: (any DoctorRepository)? = nil,
                      hospitals: (any HospitalRepository)? = nil) -> AuthFlowViewModel {
        return AuthFlowViewModel(
            repositories: .init(auth: authRepository, users: users ?? userRepository,
                                patients: patients ?? patientRepository,
                                doctors: doctors ?? doctorRepository, hospitals: hospitals ?? hospitalRepository),
            configuration: configuration,
            loginPreference: AuthLoginPreference(defaults: .standard)
        )
    }

    /// 케어콜 서비스 (설정 파일·마이크·음성 인식·음성 합성·AI 모델). 부를 때마다 새로 만들고 컨테이너는 들고 있지 않는다:
    /// 케어콜 화면을 나가 ViewModel이 사라지면 AI 모델(약 2.4GB)과 Supertonic도 함께 풀린다 (케어콜은 하루 한 번 정도라 다음에 다시 불러온다).
    /// 모델과 음성 합성은 대기 화면의 준비 단계(loadModel)에서 불러온다
    func makeCareCallService() throws -> CareCallService {
        let recorder = AVAudioEngineAdapter()
        let systemVoice = AVSpeechSynthesizerAdapter()
        return CareCallService(
            config: try Bundle.main.decodeJSON(CareCallConfig.self, named: "side_effects"),
            rules: try Bundle.main.decodeJSON(EmergencyRules.self, named: "emergency_rules"),
            bodyParts: try Bundle.main.decodeJSON(BodyPartDictionary.self, named: "body_parts"),
            recorder: recorder,
            recognizer: SpeechAnalyzerAdapter(recorder: recorder),
            systemVoice: systemVoice,
            loadAnalyzer: { try CoreAICareCallAdapter(model: try await LanguageModelProvider.loadKanana()) },
            makeVoice: { SupertonicAdapter(fallback: systemVoice) }
        )
    }

    /// 케어콜 화면에 들어갈 때마다 새로 만든다 (서비스와 같은 이유). 로그인 환자는 ViewModel이 찾는다
    @MainActor
    func makeCareCallViewModel() throws -> CareCallViewModel {
        CareCallViewModel(
            service: try makeCareCallService(),
            repository: symptomRepository,
            pending: FilePendingCareCallRepository(),
            authRepository: authRepository,
            patientRepository: patientRepository
        )
    }
}
