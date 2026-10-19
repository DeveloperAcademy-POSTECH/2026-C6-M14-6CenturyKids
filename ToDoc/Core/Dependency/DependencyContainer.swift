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
    
    init(configuration: SupabaseConfiguration) {
        supabaseProvider = SupabaseClientProvider(
            configuration: configuration
        )
    }

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
                                doctors: doctors, hospitals: hospitals, consents: consents, callbacks: callbacks),
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
}
