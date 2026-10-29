import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 2026-10-29 팀이 각자 해 본 증상 기록(노션 '증상 기록 각자 해보기')에서 나온 대화. 표에 적힌 답 그대로
@MainActor
struct TeamTryoutTests {
    let config: CareCallConfig
    let rules: EmergencyRules
    let converter: SymptomRecordConverter
    let mock = MockAnalyzer()

    init() throws {
        config = try fixture(CareCallConfig.self, "side_effects")
        rules = try fixture(EmergencyRules.self, "emergency_rules")
        converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
    }

    /// 첫 통화에서 이 항목의 유무 질문까지 "아니요"로 넘긴 상태
    private func atPresence(of key: String) async -> InterviewEngine {
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        _ = await call.handle(patientText: "괜찮아요")
        while call.phase != .slot(key: key, step: .presence) { _ = await call.handle(patientText: "아니요") }
        return call
    }

    private func saved(_ call: InterviewEngine, _ type: SymptomType) -> SymptomEntry? {
        converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.first { $0.symptomType == type }
    }

    @Test func 토는_안_했는데_속이_안_좋다면_구토_횟수를_묻지_않고_원문으로_남긴다() async {
        let answer = "토는 안했는데 속은 좀 안좋아요"
        mock.script[answer] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present)) // 실기기 모델처럼 '있음'
        let call = await atPresence(of: "nausea_vomiting")
        let next = await call.handle(patientText: answer)
        #expect(next.phase == .slot(key: "constipation", step: .presence)) // 횟수도, 같은 질문도 다시 묻지 않는다
        #expect(next.utterance.hasPrefix(config.unsureNoted))
        let entry = saved(call, .nauseaVomiting)
        #expect(entry?.presence == .unknown && entry?.detail == "[검토 필요] " + answer)
    }

    @Test(arguments: ["토는 한 번도 안 했는데 속이 계속 불편해요", "토한 적은 없는데 속이 쓰려요", "토는 안 했어요 근데 속이 좀 더부룩해요"])
    func 구토를_부정하는_여러_말투도_모름으로_남긴다(answer: String) async {
        let call = await atPresence(of: "nausea_vomiting")
        let next = await call.handle(patientText: answer)
        #expect(next.phase == .slot(key: "constipation", step: .presence))
        #expect(saved(call, .nauseaVomiting)?.presence == .unknown)
    }

    @Test func 토는_안_했다는_말은_구토_낱말로_보지_않는다() {
        let vomiting = config.effects.first { $0.id == "nausea_vomiting" }!
        #expect(!vomiting.affirmed(in: "토는 안했는데 속은 좀 안좋아요"))
        #expect(!vomiting.affirmed(in: "구토도 안 해요"))
        #expect(vomiting.affirmed(in: "토는 했는데 한 번이요"))
    }

    @Test func 네로_시작해_횟수를_말하면_횟수를_다시_묻지_않는다() async {
        let call = await atPresence(of: "diarrhea")
        let next = await call.handle(patientText: "네 어제 두 번인가 했어요")
        #expect(next.phase == .slot(key: "stomatitis", step: .presence))
        #expect(saved(call, .diarrhea)?.occurrenceCount == 2)
    }

    @Test func 생각이_잘_안_나는데요도_모름이다() async {
        let call = await atPresence(of: "neuropathy")
        let next = await call.handle(patientText: "생각이 잘 안 나는데요")
        #expect(next.phase == .slot(key: "rash_pruritus", step: .presence))
        #expect(saved(call, .numbness)?.presence == .unknown)
    }

    @Test func 모르겠는데요도_다시_묻지_않고_한마디_한_뒤_넘어간다() async {
        let call = await atPresence(of: "neuropathy")
        let next = await call.handle(patientText: "잘 모르겠는데요")
        #expect(next.phase == .slot(key: "rash_pruritus", step: .presence))
        #expect(next.utterance.hasPrefix(config.unsureNoted))
        #expect(saved(call, .numbness)?.detail == "[검토 필요] 잘 모르겠는데요")
    }

    @Test func 다시_거는_통화에서_목록_밖_증상을_말하면_받아_준_뒤_그_밖에를_묻는다() async {
        let answer = "생각해보니까 배가 좀 며칠 전부터 아팠던 거 같아요"
        mock.script[answer] = .mentions(Mention(effectId: "other", otherName: "배 아픔", presence: .present))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock, followUp: [])
        _ = call.start()
        let next = await call.handle(patientText: answer)
        #expect(next.phase == .other)
        #expect(next.utterance == config.followUpCall.notedOther + " " + config.otherQuestion)
    }

    @Test func 네네는_네로_받고_저장_내용에_남기지_않는다() async {
        let call = await atPresence(of: "diarrhea")
        let detail = await call.handle(patientText: "네네")
        #expect(detail.phase == .slot(key: "diarrhea", step: .detail))
        #expect(mock.requests.allSatisfy { $0.patientText != "네네" }) // 모델 없이 '있음'
        _ = await call.handle(patientText: "네 네") // 횟수 질문에 "네"만
        let entry = saved(call, .diarrhea)
        #expect(entry?.presence == .present && entry?.detail == nil)
    }
}
