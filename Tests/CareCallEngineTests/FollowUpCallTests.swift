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

    @Test(arguments: ["똑같아요", "그대로예요", "아니요 없어요", "괜찮아요", "비슷해요", "아까랑 같아요", "전이랑 같아요", "여전해요"])
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
        #expect(ask.phase == .opening && ask.utterance == config.followUpCall.followUp)
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

    // MARK: - 재검토 (자동 검토 지적)

    @Test(arguments: ["똑같지 않아요", "그대로가 아니에요", "그대로가아니에요", "똑같진않아요"])
    func 달라진_게_없다는_말을_부정하면_끝내지_않고_되묻는다(answer: String) async {
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: answer)
        #expect(out.phase == .opening && out.utterance == config.followUpCall.followUp)
    }

    @Test func 글쎄요라도_나빠졌다는_말이_있으면_모름으로_끝내지_않는다() async {
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: "글쎄요, 좀 안 좋아진 것 같기도 하고요")
        #expect(out.phase == .opening && out.utterance == config.followUpCall.followUp)
        #expect(call.ledger.order.isEmpty)
    }

    @Test func 분석이_실패하면_끝내지_않고_되묻고_다시_모르면_그_밖에를_묻는다() async {
        mock.failOn = ["어제 이상한 게 있었는데"]
        let call = engine()
        _ = call.start()
        let ask = await call.handle(patientText: "어제 이상한 게 있었는데")
        #expect(ask.phase == .opening && ask.utterance == config.followUpCall.followUp)
        let other = await call.handle(patientText: "음 뭐였더라")
        #expect(other.phase == .other) // 분명히 '없다'고 하지 않았으면 '그 밖에'로 한 번 더 기회를 준다
    }

    @Test func 증상_없이_나빠졌다고만_하면_그_말을_검토_필요로_남긴다() async {
        let call = engine()
        _ = call.start()
        let ask = await call.handle(patientText: "좀 안 좋아졌어요")
        #expect(ask.utterance == config.followUpCall.followUp)
        let next = await call.handle(patientText: "그냥 전반적으로요")
        let kept = call.ledger.order.compactMap { call.ledger[$0] }.first { $0.effectId == "other" }
        #expect(kept?.presence == .present && kept?.needsReview == true)
        #expect(kept?.otherName == "좀 안 좋아졌어요 / 그냥 전반적으로요")
        #expect(next.phase == .other)
        #expect(!next.utterance.hasPrefix(config.followUpCall.noted)) // 물을 증상이 없으니 "조금 더 여쭤볼게요"는 붙이지 않는다
    }

    @Test func 전에_있던_증상이_없어졌다고_하면_되묻지_않고_그_밖에를_묻는다() async {
        mock.script["설사는 멈췄어요"] = .mentions(Mention(effectId: "diarrhea", presence: .absent))
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: "설사는 멈췄어요")
        #expect(out.phase == .other) // 놓친 증상이 없는지 '그 밖에'로 한 번 묻는다
        #expect(call.ledger["diarrhea"]?.presence == .absent) // 기록에 더할 때 "다시 통화: 설사는 멈췄어요"로 남는다
        let done = await call.handle(patientText: "없어요")
        #expect(done.phase == .saved)
    }

    @Test func 없어졌다면서_다른_말이_섞이면_되묻는다() async {
        mock.script["설사는 멈췄는데 대신 머리가 좀"] = .mentions(Mention(effectId: "diarrhea", presence: .absent))
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: "설사는 멈췄는데 대신 머리가 좀")
        #expect(out.phase == .opening && out.utterance == config.followUpCall.followUp)
    }

    @Test func 긴_답은_없어요가_있어도_모델이_먼저_본다() async {
        mock.script["요즘 입맛이 좀 없어요"] = .mentions(Mention(effectId: "dehydration_nutrition", presence: .present))
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: "요즘 입맛이 좀 없어요")
        #expect(mock.requests.count >= 1)
        #expect(call.ledger["dehydration_nutrition"]?.presence == .present)
        #expect(out.phase != .saved)
    }

    @Test func 길게_말해도_모델이_찾은_게_없고_달라진_게_없다는_말이면_마친다() async {
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: "음 딱히 달라진 건 없는 것 같아요")
        #expect(mock.requests.count >= 1) // 짧은 답이 아니라 모델이 먼저 본다
        #expect(out.phase == .saved && out.utterance == config.followUpCall.unchanged + " " + rules.closingMessage)
    }

    // MARK: - 실기기 테스트 (실제 모델)

    @Test func 모델이_목록_증상에_빈_이름을_붙여도_이름_없이_기록한다() async {
        mock.script["설사를 했어요"] = .mentions(Mention(effectId: "diarrhea", otherName: "", presence: .present))
        let call = engine()
        _ = call.start()
        _ = await call.handle(patientText: "설사를 했어요")
        #expect(call.ledger["diarrhea"]?.presence == .present)
        #expect(call.ledger["diarrhea"]?.otherName == nil) // 이름이 ""이면 내용이 ": 세 번이요"로 저장됐다
    }

    @Test(arguments: ["구토는 멈췄어요", "설사가 다 나았어요", "이제 설사는 그쳤어요", "구토가 나아졌어요", "설사는 괜찮아졌어요"])
    func 모델이_못_잡아도_증상이_멈췄다고만_하면_없음으로_남기고_그_밖에를_묻는다(answer: String) async {
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: answer)
        #expect(out.phase == .other)
        let key = answer.contains("구토") ? "nausea_vomiting" : "diarrhea"
        #expect(call.ledger[key]?.presence == .absent)
    }

    @Test(arguments: [("메스꺼움이 멈췄어요", "nausea_vomiting"), ("메스꺼움이 가라앉았어요", "nausea_vomiting"),
                      ("울렁거림이 그쳤어요", "nausea_vomiting"), ("가려움이 나아졌어요", "rash_pruritus")])
    func 증상_이름이_키워드에_끝말이_붙은_말이어도_그쳤다는_말로_본다(answer: String, key: String) async {
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: answer)
        #expect(out.phase == .other)
        #expect(call.ledger[key]?.presence == .absent)
    }

    @Test(arguments: ["그럭저럭이요", "그런 것 같기도 하고요", "긴가민가해요", "헷갈려요"])
    func 애매한_답_목록의_말이면_달라진_점을_모름으로_남기고_마친다(answer: String) async {
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: answer)
        #expect(out.phase == .saved)
        #expect(call.ledger[Ledger.key(effectId: "other", otherName: config.followUpCall.unclearName)]?.presence == .unclear)
    }

    @Test(arguments: ["구토는 멈췄는데 대신 머리가 좀", "구토는 안 멈췄어요", "구토가 아직 안 나았어요", "구토는 멈추지 않았어요",
                      "구토가 계속 멈췄다가 또 해요", "설사는 멈췄고 구토는 해요", "구토는 멈춘 것 같아요", "구토는 멈췄고 머리가 아파요",
                      "구토는 다시 멈췄다가 재발했어요", "구토는 좀 나았어요", "구토는 좀 나아졌어요", "토는 멈췄어요"])
    func 멈췄다는_말이_분명하지_않으면_없음으로_넣지_않고_되묻는다(answer: String) async {
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: answer)
        // 새 증상 표현("머리가 아파요")이 있으면 언제부터인지, 아니면 무엇이 달라졌는지 묻는다
        let symptom = ["머리가 아파요"].contains(where: answer.contains)
        #expect(out.phase == .opening && out.utterance == (symptom ? config.otherDetail.question : config.followUpCall.followUp))
        #expect(call.ledger.order.isEmpty)
    }

    @Test func 모델이_고른_증상의_낱말이_없고_다른_증상_낱말만_있으면_그_증상으로_바꾼다() async {
        mock.script["요즘 입맛이 좀 없어요"] = .mentions(Mention(effectId: "stomatitis", presence: .present))
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: "요즘 입맛이 좀 없어요")
        // 구내염은 '있음'으로 남지 않는다 (다시 물어 식사로 확인되면 '모름'으로 두고 그 차례에 다시 묻는다)
        #expect(call.ledger["stomatitis"]?.presence != .present)
        #expect(call.ledger["dehydration_nutrition"]?.presence == .present)
        #expect(out.phase != .opening)
    }

    @Test func 묻지_않았는데_없어졌다고_한_말은_그대로_기록하고_물어서_아니요라고_한_답은_남기지_않는다() async throws {
        let converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
        let call = engine(unasked: ["diarrhea"])
        _ = call.start()
        let next = await call.handle(patientText: "구토가 나아졌어요")
        #expect(next.phase == .slot(key: "diarrhea", step: .presence)) // 못 물은 설사를 이어서 묻는다
        _ = await call.handle(patientText: "아니요")
        let record = converter.record(from: call.ledger, patientId: UUID(), date: Date(), followUp: true)
        #expect(record.symptoms.first { $0.symptomType == .nauseaVomiting }?.detail == "구토가 나아졌어요")
        #expect(record.symptoms.first { $0.symptomType == .diarrhea }.map { $0.presence == .absent && $0.detail == nil } == true)
        // 처음 통화 기록에는 남기지 않는다
        #expect(converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.allSatisfy { $0.detail == nil })
    }

    @Test func 한_문장에_여러_증상을_말했으면_그_문장을_없어진_증상의_말로_남기지_않는다() async throws {
        let converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
        mock.script["구토는 멈췄고 설사를 했어요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .absent),
                                                    Mention(effectId: "diarrhea", presence: .present))
        let call = engine()
        _ = call.start()
        _ = await call.handle(patientText: "구토는 멈췄고 설사를 했어요")
        let record = converter.record(from: call.ledger, patientId: UUID(), date: Date(), followUp: true)
        #expect(record.symptoms.first { $0.symptomType == .nauseaVomiting }.map { $0.presence == .absent && $0.detail == nil } == true)
    }

    @Test func 모델이_있음이라_해도_답_전체가_증상과_그쳤다는_말이면_없음으로_남긴다() async throws {
        mock.script["구토가 나아졌어요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present)) // 2026-10-19 실기기
        let converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
        let call = engine()
        _ = call.start()
        let out = await call.handle(patientText: "구토가 나아졌어요")
        #expect(out.phase == .other) // 횟수를 묻지 않는다
        let entry = converter.record(from: call.ledger, patientId: UUID(), date: Date(), followUp: true).symptoms.first
        #expect(entry?.presence == .absent && entry?.detail == "구토가 나아졌어요")
    }
}
