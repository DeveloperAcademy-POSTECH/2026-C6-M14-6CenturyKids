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
    
    init(configuration: SupabaseConfiguration) {
        supabaseProvider = SupabaseClientProvider(
            configuration: configuration
        )
        let client = supabaseProvider.client
        authRepository = SupabaseAuthRepository(client: client)
        patientRepository = SupabasePatientRepository(client: client)
        painRepository = SupabasePainRepository(client: client)
    }

    @MainActor
    func makePainRecordViewModel() -> PainRecordViewModel {
        PainRecordViewModel(
            authRepository: authRepository,
            patientRepository: patientRepository,
            painRepository: painRepository
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

    func findByPatientIdAndDate(_ patientId: UUID, _ date: Date) async throws -> SymptomRecord? { nil }
    func save(entity: SymptomRecord) async throws { throw NotConnected() }
    func findByPatientId(_ patientId: UUID) async throws -> [SymptomRecord] { [] }
    func findById(_ id: UUID) async throws -> SymptomRecord? { nil }
    func deleteById(_ id: UUID) async throws { throw NotConnected() }
}
