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
      
        let client = supabaseProvider.client
        authRepository = SupabaseAuthRepository(client: client)
        userRepository = SupabaseUserRepository(client: client)
        hospitalRepository = SupabaseHospitalRepository(client: client)
        doctorRepository = SupabaseDoctorRepository(client: client)
        patientRepository = SupabasePatientRepository(client: client)
        symptomRepository = SupabaseSymptomRepository(client: client)
        painRepository = SupabasePainRepository(client: client)
    }

    @MainActor
    func makePatientFlowViewModel() -> PatientFlowViewModel {
        PatientFlowViewModel(
            authRepository: authRepository,
            patientRepository: patientRepository
        )
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
        return SettingsViewModel(
            patientId: patientId,
            userRepository: SupabaseUserRepository(client: client),
            patientRepository: patientRepository,
            doctorRepository: SupabaseDoctorRepository(client: client),
            hospitalRepository: SupabaseHospitalRepository(client: client)

    /// 팀원이 Repository를 완성하면 이 함수의 인자로 전달합니다. VM/화면을 다시 만들 필요가 없습니다.
    /// 구현된 인증/사용자 저장소는 같은 client로 연결합니다. 나머지 nil은 의도적인 미연결입니다.
    /// 실제 DB 저장 성공을 흉내 내는 객체를 제품에 넣지 않습니다.
    @MainActor func makeAuthFlow(configuration: AuthConfiguration = .init(),
                      users: (any UserRepository)? = nil,
                      patients: (any PatientRepository)? = nil,
                      doctors: (any DoctorRepository)? = nil,
                      hospitals: (any HospitalRepository)? = nil) -> AuthFlowViewModel {
        let auth = SupabaseAuthRepository(client: supabaseProvider.client)
        return AuthFlowViewModel(
            repositories: .init(auth: auth, users: users ?? SupabaseUserRepository(client: supabaseProvider.client), patients: patients,
                                doctors: doctors, hospitals: hospitals),
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
            repository: UnconnectedSymptomRepository(),
            pending: FilePendingCareCallRepository(),
            authRepository: authRepository,
            patientRepository: patientRepository
        )
    }
}

/// SupabaseSymptomRepository가 생기면 바꿀 자리. 오늘 기록은 없는 것으로 보고 저장은 실패시킨다:
/// 받은 답은 폰(FilePendingCareCallRepository)에 남아 있다가, 실제 저장소로 바꾼 뒤 다음 케어콜에 들어갈 때 올라간다
private struct UnconnectedSymptomRepository: SymptomRepository {
    struct NotConnected: Error {}

    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [SymptomRecord] { [] }
    func save(entity: SymptomRecord) async throws { throw NotConnected() }
    func findByPatientId(_ patientId: UUID) async throws -> [SymptomRecord] { [] }
    func findById(_ id: UUID) async throws -> SymptomRecord? { nil }
    func deleteById(_ id: UUID) async throws { throw NotConnected() }
}
