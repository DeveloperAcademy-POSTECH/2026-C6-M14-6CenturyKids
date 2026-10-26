import Foundation
import Testing
@testable import ToDocCareCall

/// 이전 질문: 마지막 답을 받기 전 상태로 되돌린다. 가상 발화만
@MainActor
struct EngineBackTests {
    let config: CareCallConfig
    let engine: InterviewEngine

    init() throws {
        config = try fixture(CareCallConfig.self, "side_effects")
        engine = InterviewEngine(config: config, rules: try fixture(EmergencyRules.self, "emergency_rules"), analyzer: MockAnalyzer())
    }

    @Test func 이전_질문으로_돌아가면_그_답을_지우고_같은_질문을_다시_묻는다() async {
        _ = engine.start()
        #expect(!engine.canGoBack)
        _ = await engine.handle(patientText: "괜찮아요")
        let question = engine.lastQuestion
        let phase = engine.phase
        _ = await engine.handle(patientText: "네 있어요")
        #expect(engine.ledger["nausea_vomiting"]?.presence == .present)

        let back = engine.goBack()
        #expect(back?.answer == "네 있어요")
        #expect(back?.output.utterance == question && engine.phase == phase)
        #expect(engine.ledger["nausea_vomiting"]?.presence == nil)

        let again = await engine.handle(patientText: "없어요") // 다른 답으로 같은 대화를 이어 간다
        #expect(engine.ledger["nausea_vomiting"]?.presence == .absent)
        #expect(again.phase == .slot(key: "constipation", step: .presence))
    }

    @Test func 처음_질문까지_차례로_돌아갈_수_있다() async {
        _ = engine.start()
        _ = await engine.handle(patientText: "괜찮아요")
        _ = await engine.handle(patientText: "없어요")
        #expect(engine.goBack()?.answer == "없어요")
        #expect(engine.goBack()?.answer == "괜찮아요")
        #expect(engine.phase == .opening && engine.lastQuestion == config.openingQuestion)
        #expect(engine.ledger.conditionText == nil)
        #expect(!engine.canGoBack && engine.goBack() == nil)
    }
}
