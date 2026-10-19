//
//  DependencyContainer.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation
import SwiftUI

final class DependencyContainer {
    // SupabaseClient 보관하는 객체
    let supabaseProvider: SupabaseClientProvider
    
    init(configuration: SupabaseConfiguration) {
        supabaseProvider = SupabaseClientProvider(
            configuration: configuration
        )
    }

    /// 로그인한 환자 ID (환자 화면들이 같이 쓴다). 환자 계정이 없으면 nil, 로그인하지 않았거나 조회에 실패하면 오류
    func currentPatientId() async throws -> UUID? {
        let client = supabaseProvider.client
        let userId = try await SupabaseAuthRepository(client: client).getCurrentUserId()
        return try await SupabasePatientRepository(client: client).findById(userId)?.user.id
    }

    /// 로그인 세션이 있는지 (환자 ID 조회가 실패했을 때 로그인 문제인지 가린다)
    var isSignedIn: Bool {
        SupabaseAuthRepository(client: supabaseProvider.client).isSignedIn()
    }

    @MainActor
    func makePainRecordViewModel(patientId: UUID) -> PainRecordViewModel {
        PainRecordViewModel(
            patientId: patientId,
            painRepository: SupabasePainRepository(client: supabaseProvider.client)
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

    /// 케어콜 화면에 들어갈 때마다 새로 만든다 (서비스와 같은 이유)
    @MainActor
    func makeCareCallViewModel(patientId: UUID) throws -> CareCallViewModel {
        CareCallViewModel(
            service: try makeCareCallService(),
            repository: UnconnectedSymptomRepository(),
            pending: FilePendingCareCallRepository(),
            patientId: patientId
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

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer? = nil
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer? {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
