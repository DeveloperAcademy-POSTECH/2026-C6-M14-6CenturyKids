//
//  CareCallAI.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

/// 케어콜 AI 분석. 환자 답 한 턴을 분석해 언급된 증상을 돌려준다.
/// 다음 질문은 AI가 아니라 엔진(SlotPlanner)이 기록 상태로 정한다. 구현: FoundationModelsCareCallAdapter
protocol CareCallAI {
    func analyze(_ request: AnalysisRequest) async throws -> TurnResult
    /// 첫 분석 전에 모델을 준비해 둔다 (첫 질문을 읽어 주는 동안)
    func prewarm(_ request: AnalysisRequest) async
}

extension CareCallAI {
    func prewarm(_ request: AnalysisRequest) async {}
}

/// 엔진이 AI에 넘기는 한 턴
struct AnalysisRequest: Sendable {
    var patientText: String
    /// 지금 묻고 있는 항목 (첫 질문·그 밖에 질문에서는 nil)
    var slotKey: String?
    var slotName: String?
    var step: CareCallStep?
    var question: String
    /// 지금까지의 기록 (Ledger.summaryText)
    var ledgerSummary: String
}

/// AI가 돌려주는 한 턴의 분석 결과. AI 쪽 출력 형식(@Generable)과 분리된 타입 (변환은 FoundationModelsCareCallAdapter)
struct TurnResult: Equatable, Sendable {
    var mentions: [Mention]
    var answeredCurrentSlot: Bool
    var needsClarification: Bool
    var emergencySignal: Bool
    /// 같은 항목을 다시 물을 때 쓰는 꼬리질문 문구. 다음 항목으로 넘어갈 때는 설정 파일 문구를 쓴다
    var utterance: String
}

/// 환자 답에서 찾은 증상 하나. 기록장에 넣기 전에 Ledger.apply가 환자 말로 검증한다
struct Mention: Equatable, Sendable {
    /// side_effects.json의 id 또는 "other"
    var effectId: String
    var otherName: String? = nil
    var presence: MentionPresence
    var locations: [String] = []
    /// 근거로 단 환자 말
    var quote: String = ""
}
