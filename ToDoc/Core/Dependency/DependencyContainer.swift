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
    let patientRepository: any PatientRepository
    let painRepository: any PainRepository
    
    let authRepository: AuthRepository
    let userRepository: UserRepository
    let hospitalRepository: HospitalRepository
    let doctorRepository: DoctorRepository
    let patientRepository: PatientRepository
    let symptomRepository: any SymptomRepository
    let painRepository: any PainRepository
    
    init(configuration: SupabaseConfiguration) {
        supabaseProvider = SupabaseClientProvider(
            configuration: configuration
        )

    @MainActor
    func makePainRecordViewModel() -> PainRecordViewModel {
        PainRecordViewModel(
            authRepository: authRepository,
            patientRepository: patientRepository,
            painRepository: painRepository
        )
        
        let client = supabaseProvider.client
        
        self.authRepository = SupabaseAuthRepository(client: client)
        self.userRepository = SupabaseUserRepository(client: client)
        self.hospitalRepository = SupabaseHospitalRepository(client: client)
        self.doctorRepository = SupabaseDoctorRepository(client: client)
        self.patientRepository = SupabasePatientRepository(client: client)
        self.symptomRepository = SupabaseSymptomRepository(client: client)
        self.painRepository = SupabasePainRepository(client: client)
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
}
