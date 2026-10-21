//
//  DependencyContainer.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation

final class DependencyContainer {
    // SupabaseClient 보관하는 객체
    let supabaseProvider: SupabaseClientProvider
    let authRepository: any AuthRepository
    let userRepository: any UserRepository
    let hospitalRepository: any HospitalRepository
    let doctorRepository: any DoctorRepository
    let patientRepository: any PatientRepository
    let symptomRepository: any SymptomRepository
    let painRepository: any PainRepository
    
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

    @MainActor
    func makeNotificationSettingsViewModel() -> NotificationSettingsViewModel {
        NotificationSettingsViewModel(defaults: .standard)
    }

    /// 인증과 가입에 필요한 저장소는 컨테이너가 연결합니다.
    @MainActor func makeAuthFlow() -> AuthFlowViewModel {
        AuthFlowViewModel(
            repositories: .init(auth: authRepository, users: userRepository, patients: patientRepository,
                                doctors: doctorRepository, hospitals: hospitalRepository),
            configuration: AuthConfiguration(),
            loginPreference: AuthLoginPreference(defaults: .standard)
        )
    }

    /// 케어콜 서비스 (설정 파일·마이크·음성 인식·음성 합성·AI 모델). 부를 때마다 새로 만들고 컨테이너는 들고 있지 않는다.
    /// AI 모델은 대기 화면의 준비 단계(loadModel)에서 확인한다
    func makeCareCallService() throws -> CareCallService {
        let recorder = AVAudioEngineAdapter()
        return CareCallService(
            config: try Bundle.main.decodeJSON(CareCallConfig.self, named: "side_effects"),
            rules: try Bundle.main.decodeJSON(EmergencyRules.self, named: "emergency_rules"),
            bodyParts: try Bundle.main.decodeJSON(BodyPartDictionary.self, named: "body_parts"),
            recorder: recorder,
            recognizer: SpeechAnalyzerAdapter(recorder: recorder),
            voice: AVSpeechSynthesizerAdapter(),
            loadAnalyzer: { try FoundationModelsCareCallAdapter(model: try LanguageModelProvider.systemModel()) }
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
