import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 유무 질문에 있다고도 없다고도 하지 않은 답("그냥 좀 그래요")은 다시 묻지 않고 '모름' + 검토 필요로, 환자 말은 그대로 남긴다. 가상 발화만
@MainActor
struct VagueAnswerTests {
    let config: CareCallConfig
    let rules: EmergencyRules
    let converter: SymptomRecordConverter
    let mock = MockAnalyzer()

    init() throws {
        config = try fixture(CareCallConfig.self, "side_effects")
        rules = try fixture(EmergencyRules.self, "emergency_rules")
        converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
    }

    /// 컨디션에 답하고 첫 증상(구토) 유무 질문을 받은 상태
    private func atFirstSymptom() async -> InterviewEngine {
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        let out = await call.handle(patientText: "괜찮아요")
        #expect(out.phase == .slot(key: "nausea_vomiting", step: .presence))
        return call
    }

    @Test(arguments: ["그냥 좀 그래요", "글쎄요", "음 그저 그래요", "애매해요", "그럭저럭이요"])
    func 애매한_답은_다시_묻지_않고_모름으로_그_말을_남긴다(answer: String) async {
        let call = await atFirstSymptom()
        let next = await call.handle(patientText: answer)
        #expect(next.phase == .slot(key: "constipation", step: .presence)) // 다음 증상으로
        #expect(mock.requests.isEmpty) // 모델에 보내지 않는다
        let entry = converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.first
        #expect(entry?.symptomType == .nauseaVomiting && entry?.presence == .unknown)
        #expect(entry?.detail == "[검토 필요] " + answer)
    }

    @Test(arguments: ["그냥 그래요, 없어요", "좀 그래요, 속이 메스꺼워요", "글쎄요, 한 번 토했나", "네 그냥 그래요",
                      "그냥 그런데 어제 좀 있었어요", "아니요 그냥 그래요", "그냥 그래요, 하루 두 번", "글쎄요 한 시간쯤"])
    func 다른_말이_함께_있으면_애매한_답으로_보지_않는다(answer: String) async {
        let call = await atFirstSymptom()
        _ = await call.handle(patientText: answer)
        #expect(call.ledger["nausea_vomiting"]?.unsureAnswers.isEmpty == true)
    }

    @Test func 모르겠어요도_모름으로_그_말을_남긴다() async {
        let call = await atFirstSymptom()
        _ = await call.handle(patientText: "잘 모르겠어요")
        let entry = converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.first
        #expect(entry?.presence == .unknown && entry?.detail == "[검토 필요] 잘 모르겠어요")
    }

    @Test func 부위를_모르겠다고_하면_부위_답으로_남긴다() async {
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        _ = await call.handle(patientText: "괜찮아요")
        while call.phase != .slot(key: "neuropathy", step: .presence) { _ = await call.handle(patientText: "아니요") }
        _ = await call.handle(patientText: "네")
        _ = await call.handle(patientText: "한 30분이요") // 지속 시간
        #expect(call.phase == .slot(key: "neuropathy", step: .location))
        _ = await call.handle(patientText: "잘 모르겠어요")
        let entry = converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.first { $0.symptomType == .numbness }
        #expect(entry?.presence == .present && entry?.detail == "[검토 필요] 한 30분이요 / 부위: 잘 모르겠어요")
    }

    @Test(arguments: ["그냥 그래요", "글쎄요", "잘 모르겠어요"])
    func 그_밖에_질문에_애매하거나_모르겠다는_답은_모름으로_원문을_남기고_마무리한다(answer: String) async {
        let call = await atFirstSymptom()
        while call.phase != .other { _ = await call.handle(patientText: "아니요") }
        let requests = mock.requests.count
        let out = await call.handle(patientText: answer)
        #expect(out.phase == .saved)
        #expect(mock.requests.count == requests) // 모델에 보내지 않는다
        let others = converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.filter { $0.symptomType == .other }
        #expect(others.count == 1 && others[0].presence == .unknown) // '그냥 그래요'라는 증상 '있음'은 만들지 않는다
        #expect(others[0].detail == "[검토 필요] \(config.otherUnclearName): \(answer)")
    }

    @Test(arguments: [("하루 두 번", true), ("두세 번", true), ("한 시간쯤", true), ("삼십 분", true), ("3번", true), ("6점", true),
                      ("스물 번", true), ("이십 번", true), ("삼 회", true), ("열두 번", true),
                      ("그냥 그래요", false), ("이번에는 없어요", false), ("괜찮아요", false)])
    func 말로_한_횟수_시간도_숫자로_본다(text: String, has: Bool) {
        #expect(NumberParser.hasNumber(text) == has)
    }

    @Test func 한_번_다시_물어도_분명하지_않으면_받은_답을_원문으로_남긴다() async {
        let call = await atFirstSymptom()
        _ = await call.handle(patientText: "어떤 거 말씀이세요?")
        #expect(call.phase == .slot(key: "nausea_vomiting", step: .presence)) // 한 번 다시 물음
        let next = await call.handle(patientText: "음 그게요")
        #expect(next.phase == .slot(key: "constipation", step: .presence)) // 닫고 다음 항목
        let entry = converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.first
        #expect(entry?.presence == .unknown)
        #expect(entry?.detail == "[검토 필요] 어떤 거 말씀이세요 / 음 그게요")
    }

    @Test func 다시_물은_뒤_분명히_답하면_앞의_답은_남기지_않는다() async {
        let call = await atFirstSymptom()
        _ = await call.handle(patientText: "어떤 거 말씀이세요?")
        _ = await call.handle(patientText: "아니요")
        let entry = converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.first
        #expect(entry?.presence == .absent && entry?.detail == nil)
    }

    @Test func 다른_증상만_말하면_한_번_다시_묻고_검토_필요로_남긴_뒤_넘어간다() async {
        mock.script["설사해요"] = .mentions(Mention(effectId: "diarrhea", presence: .present))
        let call = await atFirstSymptom()
        let again = await call.handle(patientText: "설사해요") // 구토 질문에 설사 답 → 설사 기록, 구토는 한 번 다시 물음
        #expect(again.phase == .slot(key: "nausea_vomiting", step: .presence))
        #expect(again.utterance.hasPrefix(config.repeatPrefix))
        let next = await call.handle(patientText: "설사해요")
        #expect(next.phase != .slot(key: "nausea_vomiting", step: .presence)) // 더 묻지 않는다
        let nausea = converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.first { $0.symptomType == .nauseaVomiting }
        #expect(nausea?.presence == .unknown)
        #expect(nausea?.detail == "[검토 필요] 설사해요")
        #expect(call.ledger["diarrhea"]?.presence == .present)
    }

    @Test func 다시_물은_답이_또_다른_증상이어도_둘_다_검토_필요로_남긴다() async {
        mock.script["설사해요"] = .mentions(Mention(effectId: "diarrhea", presence: .present))
        mock.script["입안이 헐었어요"] = .mentions(Mention(effectId: "stomatitis", presence: .present))
        let call = await atFirstSymptom()
        _ = await call.handle(patientText: "설사해요")
        _ = await call.handle(patientText: "입안이 헐었어요")
        let nausea = converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.first { $0.symptomType == .nauseaVomiting }
        #expect(nausea?.detail == "[검토 필요] 설사해요 / 입안이 헐었어요")
    }
}
