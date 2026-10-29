import Foundation
import Testing
@testable import ToDocCareCall

/// 가상 발화만 사용. 실제 환자 정보 없음.
/// 모델 대신 규칙으로 답하는 Mock. `script`에 발화별 결과를 넣으면 그것을, 없으면 기본 규칙을 쓴다.
final class MockAnalyzer: CareCallAI {
    var script: [String: TurnResult] = [:]
    var failOn: Set<String> = []
    /// 요청(질문 항목 포함)에 따라 답을 바꿀 때
    var respond: ((AnalysisRequest) -> TurnResult?)?
    private(set) var requests: [AnalysisRequest] = []

    func analyze(_ request: AnalysisRequest) async throws -> TurnResult {
        requests.append(request)
        if failOn.contains(request.patientText) { throw CancellationError() }
        if var scripted = respond?(request) ?? script[request.patientText] {
            // 대본에서 근거를 생략하면 환자 말 전체를 근거로 (실제 모델은 근거를 써야 기록된다)
            for i in scripted.mentions.indices where scripted.mentions[i].quote.isEmpty { scripted.mentions[i].quote = request.patientText }
            return scripted
        }
        guard let key = request.slotKey, request.step == .presence else { return .empty }
        let text = request.patientText
        let presence: MentionPresence = text.contains("없") || text.contains("아니") || text.contains("괜찮") ? .absent
            : text.contains("네") || text.contains("있") ? .present : .unclear
        let id = key.hasPrefix("other:") ? "other" : key
        return TurnResult(mentions: [Mention(effectId: id, presence: presence, locations: [], quote: text)],
                          answeredCurrentSlot: presence != .unclear, needsClarification: presence == .unclear,
                          emergencySignal: false, utterance: presence == .unclear ? "조금 더 자세히 말씀해 주시겠어요?" : "")
    }

}

extension TurnResult {
    static let empty = TurnResult(mentions: [], answeredCurrentSlot: false, needsClarification: false,
                                  emergencySignal: false, utterance: "")
    static func mentions(_ m: Mention...) -> TurnResult {
        TurnResult(mentions: m, answeredCurrentSlot: true, needsClarification: false, emergencySignal: false, utterance: "")
    }
}

@MainActor
struct InterviewEngineTests {
    let config: CareCallConfig
    let rules: EmergencyRules
    let mock = MockAnalyzer()
    let engine: InterviewEngine

    init() throws {
        config = try fixture(CareCallConfig.self, "side_effects")
        rules = try fixture(EmergencyRules.self, "emergency_rules")
        engine = InterviewEngine(config: config, rules: rules, analyzer: mock)
    }

    /// 나머지 항목에 모두 "없어요"로 답해 저장까지 진행
    private func answerNoToRest() async -> InterviewEngine.Output {
        var out = InterviewEngine.Output(utterance: "", phase: engine.phase)
        for _ in 0..<40 where !out.isFinished {
            out = await engine.handle(patientText: "없어요")
        }
        return out
    }

    @Test func 먼저_언급된_부작용은_유무를_건너뛰고_횟수만_묻는다() async {
        mock.script["어제 좀 토했어요, 그거 말고는 괜찮아요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        _ = engine.start()

        let out = await engine.handle(patientText: "어제 좀 토했어요, 그거 말고는 괜찮아요")
        #expect(out.phase == .slot(key: "nausea_vomiting", step: .detail))
        #expect(out.utterance == config.openingTransition.noted + " " + config.effects[0].details[0].question)

        let next = await engine.handle(patientText: "한 번이요")
        #expect(engine.ledger["nausea_vomiting"]?.details.map(\.text) == ["한 번이요"])
        #expect(next.phase == .slot(key: "constipation", step: .presence))
        #expect(!engine.ledger["nausea_vomiting"]!.askedSteps.contains(.presence))
    }

    @Test(arguments: [
        ("네 토했어요", ["구토 횟수"]),
        ("네 속이 메스꺼워요", ["메스꺼움 시작"]),
        ("네", ["구토 횟수", "메스꺼움 시작"]), // 어느 쪽인지 말하지 않으면 둘 다
        ("네 메스꺼웠는데 토하진 않았어요", ["메스꺼움 시작"]),
    ])
    func 구토는_횟수_메스꺼움은_시작을_묻는다(answer: String, labels: [String]) async {
        _ = engine.start()
        _ = await engine.handle(patientText: "없어요") // 첫 질문
        var out = await engine.handle(patientText: answer)
        var asked: [String] = []
        while out.phase == .slot(key: "nausea_vomiting", step: .detail) {
            asked.append(out.utterance)
            out = await engine.handle(patientText: "어제부터 두 번이요")
        }
        let questions = config.effects[0].details
        #expect(asked == labels.map { label in questions.first { $0.label == label }!.question })
        #expect(engine.ledger["nausea_vomiting"]?.details.map(\.label) == labels)
        #expect(engine.ledger["nausea_vomiting"]?.followUps.isEmpty == true) // 두 번째 꼬리질문은 되묻기가 아니다
        #expect(out.phase == .slot(key: "constipation", step: .presence))
    }

    @Test func 첫_질문_답은_그대로_남기고_꼬리질문_답은_이어_붙인다() async {
        _ = engine.start()
        _ = await engine.handle(patientText: "그럭저럭이요")
        #expect(engine.ledger.conditionText == "그럭저럭이요")

        let other = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = other.start()
        let followUp = await other.handle(patientText: "좀 피곤해요")
        #expect(followUp.utterance == config.otherDetail.question) // 증상 표현: 언제부터인지 묻는다
        _ = await other.handle(patientText: "그저께부터요")
        #expect(other.ledger.conditionText == "좀 피곤해요 / 그저께부터요")
    }

    @Test func 불명확하면_한_번_다시_묻고_검토필요로_넘어간다() async {
        _ = engine.start()
        _ = await engine.handle(patientText: "없어요") // opening (Mock: 언급 없음)
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .presence))

        // "그냥 좀 그래요"·"글쎄요"는 다시 묻지 않고 바로 '모름'으로 남긴다 (VagueAnswerTests). 모델이 불명확하다고 본 답만 다시 묻는다
        let f1 = await engine.handle(patientText: "어떤 거 말씀이세요?")
        #expect(f1.phase == .slot(key: "nausea_vomiting", step: .presence))
        let ask = engine.config.effects.first { $0.id == "nausea_vomiting" }!.ask
        #expect(f1.utterance == engine.config.repeatPrefix + " " + ask) // 모델 꼬리질문은 쓰지 않고 같은 질문을 다시 한다
        // 다시 묻는 건 한 번만: 또 분명하지 않으면 닫고 다음 항목
        let moved = await engine.handle(patientText: "음 그게요")

        #expect(moved.phase == .slot(key: "constipation", step: .presence))
        #expect(engine.ledger["nausea_vomiting"]?.followUps[.presence] == 1)
        #expect(engine.ledger["nausea_vomiting"]?.needsReview == true)
    }

    @Test func 응급으로_끝나도_그때까지의_답과_응급으로_끝낸_말을_저장한다() async throws {
        _ = engine.start()
        _ = await engine.handle(patientText: "괜찮아요")
        _ = await engine.handle(patientText: "네 있어요") // 구토 있음
        while engine.phase != .slot(key: "constipation", step: .presence) { _ = await engine.handle(patientText: "어제부터요") }
        let out = await engine.handle(patientText: "변 볼 때 빨간 피가 묻어 나와요")
        #expect(out.phase == .emergencyEnded)
        let converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
        let record = converter.record(from: engine.ledger, patientId: UUID(), date: Date())
        #expect(record.conditionText == "괜찮아요")
        #expect(record.symptoms.map(\.symptomType) == [.nauseaVomiting, .other]) // 묻던 변비는 답이 없어 빼고
        #expect(record.symptoms.first?.presence == .present)
        #expect(record.symptoms.last?.presence == .unknown)
        #expect(record.symptoms.last?.detail == "[검토 필요] \(rules.endedName): 변 볼 때 빨간 피가 묻어 나와요")
    }

    @Test func 응급_키워드면_고정문구로_종료하고_플래그를_남긴다() async {
        _ = engine.start()
        let out = await engine.handle(patientText: "어제부터 숨이 차고 열이 39도까지 났어요")
        #expect(out.phase == .emergencyEnded)
        #expect(out.utterance == rules.message)
        #expect(mock.requests.isEmpty) // 키워드 규칙이 모델 호출보다 먼저

        let after = await engine.handle(patientText: "네")
        #expect(after.utterance.isEmpty && after.isFinished)
    }

    /// 모델만 응급이라고 한 첫 답 (응급 키워드·체온에는 안 걸림)
    private func modelOnlyEmergency() async -> InterviewEngine.Output {
        var signal = TurnResult.mentions(Mention(effectId: "nausea_vomiting", presence: .present),
                                         Mention(effectId: "stomatitis", presence: .present),
                                         Mention(effectId: "neuropathy", presence: .present, locations: ["손"]))
        signal.emergencySignal = true
        mock.script["토하고 입안도 아프고 손도 저려요"] = signal
        _ = engine.start()
        return await engine.handle(patientText: "토하고 입안도 아프고 손도 저려요")
    }

    @Test func 모델만_응급이라고_하면_한_번_확인하고_아니면_이어_가며_그_답의_기록은_검토_필요() async {
        let check = await modelOnlyEmergency()
        #expect(check.utterance == rules.confirmQuestion && check.phase == .opening)
        for key in ["nausea_vomiting", "stomatitis", "neuropathy"] {
            #expect(engine.ledger[key]?.needsReview == true, "\(key)")
        }
        let out = await engine.handle(patientText: "아니요, 그 정도는 아니에요")
        #expect(out.utterance == config.openingTransition.noted + " " + config.effects[0].details[0].question)
        #expect(out.phase == .slot(key: "nausea_vomiting", step: .detail))
        _ = await engine.handle(patientText: "한 번이요") // 구토 횟수
        _ = await engine.handle(patientText: "없어요")   // 변비 (그 뒤에 받은 기록은 표시하지 않는다)
        #expect(engine.ledger["constipation"]?.presence == .absent && engine.ledger["constipation"]?.needsReview == false)
    }

    @Test func 모델이_응급이라고_본_답은_저장할_기록에_검토_필요로_남는다() async throws {
        _ = await modelOnlyEmergency()
        let converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
        let record = converter.record(from: engine.ledger, patientId: UUID(), date: Date())
        #expect(!record.symptoms.isEmpty)
        #expect(record.symptoms.allSatisfy { $0.detail?.hasPrefix("[검토 필요]") == true })
    }

    @Test func 모델이_응급이라고_본_답이_기록되지_않았으면_그_말을_모름으로_남긴다() async throws {
        var signal = TurnResult.empty
        signal.emergencySignal = true
        mock.script["변 볼 때 뭐가 이상하게 나와요"] = signal
        await reach("constipation")
        let check = await engine.handle(patientText: "변 볼 때 뭐가 이상하게 나와요")
        #expect(check.utterance == rules.confirmQuestion)
        let out = await engine.handle(patientText: "아니요")
        #expect(out.phase == .slot(key: "constipation", step: .presence)) // 아니라고 하면 이어 간다 (변비는 다시 묻는다)
        // 모델 판단만으로 '있음' 증상을 만들지 않는다 (유무 모름, 원문은 검토 필요로)
        let entry = engine.ledger["other:" + rules.reviewName]
        #expect(entry?.presence == .unclear && entry?.needsReview == true)
        #expect(entry?.unsureAnswers == ["변 볼 때 뭐가 이상하게 나와요"])
        #expect(!engine.ledger.order.contains { engine.ledger[$0]?.presence == .present })
        let converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
        let note = converter.record(from: engine.ledger, patientId: UUID(), date: Date()).symptoms.filter { $0.symptomType == .other }
        #expect(note.map(\.presence) == [.unknown])
        #expect(note.first?.detail == "[검토 필요] \(rules.reviewName): 변 볼 때 뭐가 이상하게 나와요")
    }

    /// 묻는 항목까지 "없어요"로 넘어간다
    @Test func 유무_질문에_다른_이야기를_한_답도_그_항목에_원문으로_남긴다() async throws {
        mock.script["숨이 잘 안 쉬어져요"] = .mentions(Mention(effectId: "stomatitis", presence: .present, locations: [], quote: ""))
        await reach("stomatitis")
        _ = await engine.handle(patientText: "숨이 잘 안 쉬어져요")
        #expect(engine.ledger["stomatitis"]?.answers == ["숨이 잘 안 쉬어져요"])
        let converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
        let saved = converter.record(from: engine.ledger, patientId: UUID(), date: Date()).symptoms.first { $0.symptomType == .oralPain }
        #expect(saved?.detail?.hasPrefix("숨이 잘 안 쉬어져요") == true)
    }

    @Test func 그냥_없다는_답은_원문으로_남기지_않는다() async {
        mock.script["입안이 헐어서 따가워요"] = .mentions(Mention(effectId: "stomatitis", presence: .present, locations: [], quote: ""))
        await reach("stomatitis")
        _ = await engine.handle(patientText: "입안이 헐어서 따가워요")
        #expect(engine.ledger["stomatitis"]?.answers == ["입안이 헐어서 따가워요"])
        // 다음 항목: 모델이 그냥 '없음'으로 본 긴 답
        mock.script["손발은 아무렇지도 않아요"] = .mentions(Mention(effectId: "neuropathy", presence: .absent, locations: [], quote: ""))
        for _ in 0..<5 where engine.phase != .slot(key: "neuropathy", step: .presence) { _ = await engine.handle(patientText: "어제부터요") }
        _ = await engine.handle(patientText: "손발은 아무렇지도 않아요")
        #expect(engine.ledger["neuropathy"]?.presence == .absent)
        #expect(engine.ledger["neuropathy"]?.answers.isEmpty == true)
    }

    @Test func 다른_것이_없다는_답은_모델로_보고_원문을_남긴다() async {
        await reach("nausea_vomiting")
        _ = await engine.handle(patientText: "다리에 힘이 하나도 없어요")
        #expect(mock.requests.last?.patientText == "다리에 힘이 하나도 없어요")
        #expect(engine.ledger["nausea_vomiting"]?.answers == ["다리에 힘이 하나도 없어요"])
    }

    @Test(arguments: ["헌 데가 없어요", "그런 적이 없어요", "별 이상이 없어요", "입안에 헌 데가 하나도 없어요"])
    func 가리키는_말이나_이_항목이_주어면_그냥_없다는_답(answer: String) async {
        await reach("stomatitis")
        let asked = mock.requests.count
        _ = await engine.handle(patientText: answer)
        #expect(mock.requests.count == asked) // 모델 없이 '없음'
        #expect(engine.ledger["stomatitis"]?.presence == .absent)
        #expect(engine.ledger["stomatitis"]?.answers.isEmpty == true)
    }

    @Test func 없다는_말_뒤에_다른_이야기를_하면_원문을_남긴다() async {
        mock.script["변비는 모르겠고 소변볼 때 따끔거려요"] = .mentions(Mention(effectId: "constipation", presence: .absent, locations: [], quote: ""))
        await reach("constipation")
        _ = await engine.handle(patientText: "변비는 모르겠고 소변볼 때 따끔거려요")
        #expect(engine.ledger["constipation"]?.answers == ["변비는 모르겠고 소변볼 때 따끔거려요"])
    }

    @Test func 다른_것이_주어인_답을_모델이_다른_항목으로_골라도_지금_항목으로_옮기지_않는다() async {
        mock.script["오른쪽 팔에 힘이 없어요"] = .mentions(Mention(effectId: "neuropathy", presence: .present, locations: ["팔"], quote: ""))
        await reach("dehydration_nutrition")
        _ = await engine.handle(patientText: "오른쪽 팔에 힘이 없어요")
        #expect(engine.ledger["dehydration_nutrition"]?.presence != .present)
        #expect(engine.ledger["neuropathy"]?.presence != .present) // 저림 낱말이 없다
        let other = engine.ledger["other:오른쪽 팔에 힘이 없어요"]
        #expect(other?.presence == .present && other?.needsReview == true)
    }

    @Test func 다른_목록_증상으로_기록된_답은_그_증상에_원문을_남긴다() async {
        mock.script["발바닥에 감각이 거의 없어요"] = .mentions(Mention(effectId: "neuropathy", presence: .present, locations: ["발"], quote: ""))
        await reach("diarrhea")
        _ = await engine.handle(patientText: "발바닥에 감각이 거의 없어요")
        #expect(engine.ledger["neuropathy"]?.presence == .present)
        #expect(engine.ledger["neuropathy"]?.answers == ["발바닥에 감각이 거의 없어요"])
        #expect(engine.ledger["diarrhea"]?.answers.isEmpty != false)
    }

    @Test func 되물은_답도_원문으로_남긴다() async {
        var asked = TurnResult.empty
        asked.needsClarification = true
        mock.script["목소리가 잘 안 나와요"] = asked
        await reach("rash_pruritus")
        let out = await engine.handle(patientText: "목소리가 잘 안 나와요")
        #expect(out.phase == .slot(key: "rash_pruritus", step: .presence)) // 다시 묻는다
        _ = await engine.handle(patientText: "아니요")
        #expect(engine.ledger["rash_pruritus"]?.presence == .absent)
        #expect(engine.ledger["rash_pruritus"]?.answers == ["목소리가 잘 안 나와요"])
    }

    private func reach(_ key: String) async {
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .slot(key: key, step: .presence) {
            _ = await engine.handle(patientText: "없어요")
        }
    }

    @Test(arguments: [("constipation", "변은 잘 나와요"), ("dehydration_nutrition", "평소만큼 먹어요"),
                      ("stomatitis", "입은 괘안십니더"), ("rash_pruritus", "가려운 데는 읎심더")])
    func 정상이라는_답과_사투리_부정은_모델_없이_없음(key: String, answer: String) async {
        await reach(key)
        _ = await engine.handle(patientText: answer)
        #expect(engine.ledger[key]?.presence == .absent)
        #expect(!mock.requests.contains { $0.patientText == answer })
    }

    @Test func 한_항목의_정상이라는_말은_그_항목을_물을_때만_모델_없이_없음() async {
        await reach("stomatitis")
        _ = await engine.handle(patientText: "침은 잘 나와요") // "잘 나와요"는 변비의 말
        #expect(mock.requests.contains { $0.patientText == "침은 잘 나와요" })
    }

    @Test func 그_밖에_질문에_어느_항목의_정상이라는_말은_기타_증상으로_남기지_않는다() async {
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        _ = await engine.handle(patientText: "변은 잘 나와요")
        #expect(!engine.ledger.order.contains { $0.hasPrefix("other:") })
    }

    @Test func 부위의_상태만_말하면_다른_항목_이야기일_수_있어_모델이_본다() async {
        await reach("constipation")
        _ = await engine.handle(patientText: "입은 멀쩡해요")
        #expect(mock.requests.contains { $0.patientText == "입은 멀쩡해요" })
    }

    @Test func 잘_안_된다는_답을_모델이_없음이라_하면_다시_묻는다() async {
        mock.script["입맛이 영 안 좋아요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .absent))
        await reach("nausea_vomiting")
        let out = await engine.handle(patientText: "입맛이 영 안 좋아요")
        #expect(engine.ledger["nausea_vomiting"]?.presence == nil)
        #expect(out.phase == .slot(key: "nausea_vomiting", step: .presence))
        #expect(out.utterance.hasPrefix(config.repeatPrefix))
    }

    @Test(arguments: ["잘 안 나와요", "사흘째 큰일을 못 봤어요", "배에 힘을 줘도 소식이 없어요"])
    func 변비_질문에_안_나온다는_답은_모델이_없음이라_해도_있음(answer: String) async {
        mock.script[answer] = .mentions(Mention(effectId: "constipation", presence: .absent))
        await reach("constipation")
        _ = await engine.handle(patientText: answer)
        #expect(engine.ledger["constipation"]?.presence == .present)
    }

    @Test(arguments: ["안 나오는 건 없어요", "못 볼 정도는 아니에요"])
    func 안_나온다는_말을_부정하면_있음이_아니다(answer: String) async {
        mock.script[answer] = .mentions(Mention(effectId: "constipation", presence: .absent))
        await reach("constipation")
        _ = await engine.handle(patientText: answer)
        #expect(engine.ledger["constipation"]?.presence != .present)
    }

    @Test func 그_밖에의_안_나온다는_말은_변비로_보지_않는다() async {
        await reach("constipation")
        while engine.phase != .other { _ = await engine.handle(patientText: "아니요") }
        _ = await engine.handle(patientText: "목소리가 잘 안 나와요")
        #expect(engine.ledger["constipation"]?.presence == .absent)
    }

    @Test(arguments: [("한 그릇 싹 비워요", true), ("밥이랑 반찬 다 비우고 있어요", true), ("반 그릇도 못 비워요", false),
                      ("겨우 반만 비워요", false)])
    func 식사_질문에_그릇을_비운다는_답은_없음(answer: String, usual: Bool) async {
        mock.script[answer] = .mentions(Mention(effectId: "dehydration_nutrition", presence: .present))
        await reach("dehydration_nutrition")
        _ = await engine.handle(patientText: answer)
        #expect((engine.ledger["dehydration_nutrition"]?.presence == .absent) == usual)
    }

    @Test(arguments: [("밥 두 공기 뚝딱 먹어요", true), ("보리차를 자주 마셔요", true), ("밥을 반 공기만 먹어요", false),
                      ("죽만 조금 먹어요", false), ("먹긴 먹는데 많이 못 먹어요", false), ("입맛이 없어서 겨우 먹어요", false)])
    func 식사_질문에_줄었다는_말_없이_먹는다고만_하면_없음(answer: String, usual: Bool) async {
        mock.script[answer] = .mentions(Mention(effectId: "dehydration_nutrition", presence: .present))
        await reach("dehydration_nutrition")
        _ = await engine.handle(patientText: answer)
        #expect((engine.ledger["dehydration_nutrition"]?.presence == .absent) == usual)
    }

    @Test func 다른_증상_이야기에_지금_항목을_있음이라_하면_다시_묻는다() async {
        mock.script["입맛이 없어서 조금밖에 못 먹어요"] = .mentions(Mention(effectId: "stomatitis", presence: .present))
        mock.script["네, 입맛도 없어요"] = .mentions(Mention(effectId: "stomatitis", presence: .present))
        await reach("stomatitis")
        let out = await engine.handle(patientText: "입맛이 없어서 조금밖에 못 먹어요")
        #expect(engine.ledger["stomatitis"]?.presence == nil)
        #expect(out.utterance.hasPrefix(config.repeatPrefix))
        _ = await engine.handle(patientText: "네, 입맛도 없어요") // "네"로 시작: 지금 항목의 답
        #expect(engine.ledger["stomatitis"]?.presence == .present)
    }

    @Test func 모두_없음이면_7개를_한번씩_묻고_기타_요약_저장() async {
        _ = engine.start()
        var asked: [String] = []
        var out = InterviewEngine.Output(utterance: "", phase: engine.phase)
        for _ in 0..<40 where !out.isFinished {
            out = await engine.handle(patientText: "없어요")
            asked.append("AI: " + out.utterance)
        }
        #expect(out.phase == .saved)
        #expect(out.utterance == rules.closingMessage)
        for effect in config.effects {
            #expect(asked.filter { $0.hasSuffix(effect.ask) }.count == 1, "\(effect.id)")
        }
        #expect(asked.contains("AI: \(config.otherQuestion)"))
    }

    @Test func 부위는_환자가_말한_것만_기록한다() async {
        mock.script["손이 저려요"] = .mentions(Mention(effectId: "neuropathy", presence: .present,
                                                      locations: ["손", "발"]))
        _ = engine.start()
        _ = await engine.handle(patientText: "손이 저려요")
        #expect(engine.ledger["neuropathy"]?.locations == ["손"])
    }

    @Test func 부위_대상은_횟수_다음에_부위를_묻는다() async {
        mock.script["손발이 좀 저려요"] = .mentions(Mention(effectId: "neuropathy", presence: .present))
        _ = engine.start()
        _ = await engine.handle(patientText: "손발이 좀 저려요")
        while engine.phase != .slot(key: "neuropathy", step: .detail) {
            _ = await engine.handle(patientText: "없어요")
        }
        let out = await engine.handle(patientText: "어제부터요")
        #expect(out.phase == .slot(key: "neuropathy", step: .location))
        #expect(out.utterance == config.locationPrompt)
    }

    @Test func 번복하면_최신값으로_바꾸고_검토필요() async {
        mock.script["아까 토했어요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        _ = engine.start()
        _ = await engine.handle(patientText: "없어요")            // opening
        _ = await engine.handle(patientText: "구토는 없어요")       // nausea: absent
        #expect(engine.ledger["nausea_vomiting"]?.presence == .absent)
        _ = await engine.handle(patientText: "아까 토했어요")       // constipation 질문 중 번복
        #expect(engine.ledger["nausea_vomiting"]?.presence == .present)
        #expect(engine.ledger["nausea_vomiting"]?.needsReview == true)
        // 순서상 앞 항목이 미완이 되었으므로 횟수부터 묻는다
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .detail))
    }

    @Test func 기타_부작용은_한_번_더_묻고_답을_그대로_기록한_뒤_마무리() async {
        // 환자 말에 없는 이름("두통")은 쓰지 않고 발화 그대로 기록
        mock.script["머리가 아파요"] = .mentions(Mention(effectId: "other", otherName: "두통", presence: .present))
        _ = engine.start()
        while engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        let out = await engine.handle(patientText: "머리가 아파요")
        #expect(out.phase == .other && out.utterance == config.otherDetail.question)
        let summary = await engine.handle(patientText: "오후만 되면 지끈거려요")
        #expect(engine.ledger["other:머리가 아파요"]?.details.map(\.text) == ["오후만 되면 지끈거려요"])
        #expect(engine.phase == .saved)
        #expect(summary.utterance == config.otherDetail.recorded + " " + rules.closingMessage)
    }

    @Test func 그_밖에_네만_답하면_되묻고_그_답은_다시_묻지_않는다() async {
        mock.script["열이 조금 나요"] = .mentions(Mention(effectId: "other", otherName: "열", presence: .present))
        _ = engine.start()
        while engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        let ask = await engine.handle(patientText: "네")
        #expect(ask.phase == .other && ask.utterance == config.otherFollowUp)
        let summary = await engine.handle(patientText: "열이 조금 나요")
        #expect(engine.ledger["other:열"]?.presence == .present)
        #expect(engine.phase == .saved)
        #expect(summary.utterance.hasPrefix(config.otherDetail.recorded + " "))
    }

    @Test func 그_밖에_없다고_하면_바로_마무리() async {
        _ = engine.start()
        while engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        let out = await engine.handle(patientText: "없어요")
        #expect(engine.phase == .saved && out.utterance == rules.closingMessage)
    }

    @Test func 모델_호출_실패는_세고_같은_질문을_다시_묻는다() async {
        mock.failOn = ["???"]
        _ = engine.start()
        _ = await engine.handle(patientText: "없어요")
        let out = await engine.handle(patientText: "???")
        #expect(mock.requests.filter { $0.patientText == "???" }.count == 1) // 취소 오류는 다시 분석하지 않는다
        #expect(out.phase == .slot(key: "nausea_vomiting", step: .presence))
        #expect(engine.ledger["nausea_vomiting"]?.followUps[.presence] == 1)
    }
}

@MainActor
struct NumberWordTests {
    @Test(arguments: [
        ("한 6점 정도요", Set([6])),
        ("10점이요", Set([10])),
        ("0점", Set([0])),
        ("여섯 점", Set([6])),
        ("칠점이요", Set([7])),
        ("많이 아파요", Set<Int>()),
        ("열이 39도예요", Set<Int>()),
        ("이가 아파요", Set<Int>()),
        ("2~3점", Set([2, 3])),
    ])
    func 숫자만_인정(text: String, expected: Set<Int>) {
        #expect(NumberParser.numbers(in: text) == expected)
    }
}
