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
                      "그냥 그런데 어제 좀 있었어요", "아니요 그냥 그래요"])
    func 다른_말이_함께_있으면_애매한_답으로_보지_않는다(answer: String) async {
        let call = await atFirstSymptom()
        _ = await call.handle(patientText: answer)
        #expect(call.ledger["nausea_vomiting"]?.vagueAnswer == nil)
    }

    @Test func 모르겠어요는_지금처럼_말을_남기지_않고_모름() async {
        let call = await atFirstSymptom()
        _ = await call.handle(patientText: "잘 모르겠어요")
        let entry = converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.first
        #expect(entry?.presence == .unknown && entry?.detail == "[검토 필요]")
    }
}
