import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 같은 날 다시 거는 케어콜: "달라졌거나 새로 불편한 점"을 묻고, 말한 증상과 지난 통화에서 못 물은 항목만 묻는다. 가상 발화만
@MainActor
struct FollowUpCallTests {
    let config: CareCallConfig
    let rules: EmergencyRules
    let mock = MockAnalyzer()

    init() throws {
        config = try fixture(CareCallConfig.self, "side_effects")
        rules = try fixture(EmergencyRules.self, "emergency_rules")
    }

    private func engine(unasked: Set<String> = []) -> InterviewEngine {
        InterviewEngine(config: config, rules: rules, analyzer: mock, followUp: unasked)
    }

    private func effect(_ id: String) -> CareCallConfig.Effect { config.effects.first { $0.id == id }! }

    @Test func 다시_거는_통화는_달라진_점을_묻는다() {
        let call = engine()
        #expect(call.start().utterance == config.followUpCall.question)
        #expect(call.lastQuestion == config.followUpCall.question)
    }

    @Test(arguments: ["똑같아요", "그대로예요", "아니요 없어요", "괜찮아요", "비슷해요"])
    func 달라진_게_없으면_그대로_둔다고_하고_바로_마친다(answer: String) async {
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: answer)
        #expect(out.phase == .saved)
        #expect(out.utterance == config.followUpCall.unchanged + " " + rules.closingMessage)
        #expect(call.ledger.order.isEmpty)
        #expect(call.ledger.conditionText == nil) // 다시 거는 통화는 컨디션을 묻지 않는다
        #expect(mock.requests.isEmpty)
    }

    @Test func 말한_증상만_세부를_묻고_그_밖에로_마친다() async {
        mock.script["설사를 했어요, 손도 저리고요"] = .mentions(Mention(effectId: "diarrhea", presence: .present),
                                                    Mention(effectId: "neuropathy", presence: .present, locations: ["손"]))
        let call = engine()
        _ = call.start()
        let first = await call.handle(patientText: "설사를 했어요, 손도 저리고요")
        #expect(first.phase == .slot(key: "diarrhea", step: .detail))
        #expect(first.utterance.hasPrefix(config.followUpCall.noted))
        let numbness = await call.handle(patientText: "세 번이요")
        #expect(numbness.phase == .slot(key: "neuropathy", step: .detail)) // 다른 항목(구내염 등)은 묻지 않는다
        let other = await call.handle(patientText: "한 30분이요")
        #expect(other.phase == .other)
        let done = await call.handle(patientText: "없어요")
        #expect(done.phase == .saved)
        #expect(call.ledger.order.filter { call.ledger[$0]?.presence != nil } == ["diarrhea", "neuropathy"])
    }

    @Test func 지난_통화에서_못_물은_항목은_평소처럼_이어서_묻는다() async {
        let call = engine(unasked: ["rash_pruritus", "dehydration_nutrition"])
        _ = call.start()
        let out = await call.handle(patientText: "똑같아요")
        #expect(out.phase == .slot(key: "rash_pruritus", step: .presence))
        #expect(out.utterance == config.followUpCall.resume + " " + effect("rash_pruritus").ask)
        let next = await call.handle(patientText: "아니요")
        #expect(next.phase == .slot(key: "dehydration_nutrition", step: .presence))
        let other = await call.handle(patientText: "아니요")
        #expect(other.phase == .other) // 못 물은 항목을 물었으면 '그 밖에'로 마무리
    }

    @Test func 말한_증상과_못_물은_항목을_함께_묻는다() async {
        mock.script["구토를 했어요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        let call = engine(unasked: ["dehydration_nutrition"])
        _ = call.start()
        let out = await call.handle(patientText: "구토를 했어요")
        #expect(out.phase == .slot(key: "nausea_vomiting", step: .detail))
        #expect(out.utterance.hasPrefix(config.followUpCall.notedAndResume))
        let next = await call.handle(patientText: "두 번이요")
        #expect(next.phase == .slot(key: "dehydration_nutrition", step: .presence))
    }

    @Test func 글쎄요면_달라진_점을_모름으로_남기고_마친다() async {
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: "글쎄요")
        #expect(out.phase == .saved)
        #expect(out.utterance == rules.closingMessage)
        let key = Ledger.key(effectId: "other", otherName: config.followUpCall.unclearName)
        #expect(call.ledger[key]?.presence == .unclear)
        #expect(call.ledger[key]?.needsReview == true)
    }

    @Test func 네만_답하면_무엇이_달라졌는지_되묻는다() async {
        mock.script["설사를 했어요"] = .mentions(Mention(effectId: "diarrhea", presence: .present))
        let call = engine()
        _ = call.start()
        let ask = await call.handle(patientText: "네")
        #expect(ask.phase == .opening && ask.utterance == config.openingFollowUp)
        #expect(mock.requests.isEmpty)
        let out = await call.handle(patientText: "설사를 했어요")
        #expect(out.phase == .slot(key: "diarrhea", step: .detail))
    }

    @Test func 달라진_게_없다면서_증상을_말하면_모델이_본다() async {
        mock.script["똑같은데 어제 설사를 했어요"] = .mentions(Mention(effectId: "diarrhea", presence: .present))
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: "똑같은데 어제 설사를 했어요")
        #expect(mock.requests.count >= 1)
        #expect(out.phase == .slot(key: "diarrhea", step: .detail))
    }

    @Test func 처음_통화는_그대로_컨디션부터_묻는다() async {
        let first = InterviewEngine(config: config, rules: rules, analyzer: mock)
        #expect(first.start().utterance == config.openingQuestion)
        let out = await first.handle(patientText: "똑같아요")
        #expect(out.phase != .saved)
    }
}
