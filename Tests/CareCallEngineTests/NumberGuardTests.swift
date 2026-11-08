import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 숫자가 섞인 답은 짧은 답 규칙('없음'·'모름'·'달라진 게 없음')으로 처리하지 않고 모델이 본다.
/// 강도 점수를 묻던 때의 숫자 확인(0~10, "N점")은 "한 번", "두 시간"을 못 봐서 숫자가 사라졌다. 가상 발화만
@MainActor
struct NumberGuardTests {
    let config: CareCallConfig
    let rules: EmergencyRules
    let mock = MockAnalyzer()

    init() throws {
        config = try fixture(CareCallConfig.self, "side_effects")
        rules = try fixture(EmergencyRules.self, "emergency_rules")
    }

    /// 컨디션에 답하고 첫 증상(구토) 유무 질문을 받은 상태
    private func atFirstSymptom() async -> InterviewEngine {
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        _ = await call.handle(patientText: "괜찮아요")
        #expect(call.phase == .slot(key: "nausea_vomiting", step: .presence))
        return call
    }

    @Test func 한_번밖에_안_했어요는_없음이_아니라_모델이_본다() async {
        let call = await atFirstSymptom()
        _ = await call.handle(patientText: "한 번밖에 안 했어요")
        #expect(mock.requests.count == 1) // 예전에는 "안 했어요"로 끝나 모델 없이 '없음'
    }

    @Test func 모르겠다면서_횟수를_말하면_모델이_본다() async {
        let call = await atFirstSymptom()
        _ = await call.handle(patientText: "잘 모르겠어요 한 두 번?")
        #expect(mock.requests.count == 1)
        #expect(call.ledger["nausea_vomiting"]?.unknownSteps.isEmpty == true)
    }

    @Test func 다시_거는_통화에서_똑같다면서_횟수를_말하면_끝내지_않는다() async {
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock, followUp: [])
        _ = call.start()
        let out = await call.handle(patientText: "똑같아요, 하루 두 번")
        #expect(out.phase != .saved) // 예전에는 '달라진 게 없음'으로 바로 마침
    }

    @Test func 그_밖에_질문에_모르겠다면서_숫자를_말해도_있음이_아니라_모름으로_원문을_남긴다() async {
        let call = await atFirstSymptom()
        while call.phase != .other { _ = await call.handle(patientText: "아니요") }
        let out = await call.handle(patientText: "잘 모르겠어요 두 번쯤?") // 모델이 본다 (가짜 모델은 아무것도 찾지 않음)
        #expect(out.phase == .saved)
        let others = call.ledger.order.compactMap { call.ledger[$0] }.filter { $0.effectId == "other" }
        #expect(others.count == 1 && others[0].presence == .unclear)
        #expect(others[0].unsureAnswers == ["잘 모르겠어요 두 번쯤"])
    }

    @Test func 다시_거는_통화에서_글쎄요와_숫자는_모델이_보고_찾은_게_없으면_원문을_남기고_되묻는다() async {
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock, followUp: [])
        _ = call.start()
        let out = await call.handle(patientText: "글쎄요 두 번?")
        #expect(mock.requests.count == 1) // 숫자가 섞이면 모델이 본다
        #expect(out.phase == .opening && out.utterance == config.followUpCall.followUp) // 바로 끝내지 않고 되묻는다
        let key = Ledger.key(effectId: "other", otherName: config.followUpCall.unclearName)
        #expect(call.ledger[key]?.presence == .unclear)
        #expect(call.ledger[key]?.unsureAnswers == ["글쎄요 두 번"])
    }

    @Test func 그_밖에_질문에_모르겠다면서_증상을_말하면_모름이_아니라_증상으로_남긴다() async {
        let call = await atFirstSymptom()
        while call.phase != .other { _ = await call.handle(patientText: "아니요") }
        _ = await call.handle(patientText: "잘 모르겠는데 머리가 아파요") // 가짜 모델은 아무것도 찾지 않음
        let others = call.ledger.order.compactMap { call.ledger[$0] }.filter { $0.effectId == "other" }
        #expect(others.count == 1 && others[0].presence == .present && others[0].needsReview)
    }

    @Test func 다시_거는_통화에서_되물은_답의_증상은_달라진_점_이름으로_붙지_않는다() async {
        mock.script["머리가 좀 아파요"] = .mentions(Mention(effectId: "headache", presence: .present))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock, followUp: [])
        _ = call.start()
        _ = await call.handle(patientText: "글쎄요 두 번?")
        _ = await call.handle(patientText: "머리가 좀 아파요")
        let unclearKey = Ledger.key(effectId: "other", otherName: config.followUpCall.unclearName)
        #expect(call.ledger[unclearKey]?.presence == .unclear) // '달라진 점'은 모름 그대로
        #expect(call.ledger.order.contains { $0 != unclearKey && $0.hasPrefix("other:") && call.ledger[$0]?.presence == .present })
    }
}
