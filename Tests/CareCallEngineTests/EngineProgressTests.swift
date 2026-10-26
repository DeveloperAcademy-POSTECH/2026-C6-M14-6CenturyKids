import Foundation
import Testing
@testable import ToDocCareCall

/// 화면에 보일 진행률과 꼬리질문 표시. 가상 발화만
@MainActor
struct EngineProgressTests {
    let engine: InterviewEngine

    init() throws {
        engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                 rules: try fixture(EmergencyRules.self, "emergency_rules"), analyzer: MockAnalyzer())
    }

    @Test func 진행률은_답할수록_늘고_마치면_1() async {
        _ = engine.start()
        #expect(engine.progress == 0)
        _ = await engine.handle(patientText: "괜찮아요")
        let first = engine.progress
        #expect(first > 0)
        _ = await engine.handle(patientText: "없어요")
        #expect(engine.progress > first && engine.progress < 1)
        var out = InterviewEngine.Output(utterance: "", phase: engine.phase)
        for _ in 0..<40 where !out.isFinished { out = await engine.handle(patientText: "없어요") }
        #expect(engine.progress == 1)
    }

    @Test func 꼬리질문이면_더_묻는_질문으로_표시한다() async {
        _ = engine.start()
        _ = await engine.handle(patientText: "괜찮아요")
        #expect(!engine.asksMore) // 유무 질문
        _ = await engine.handle(patientText: "네 있어요")
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .detail) && engine.asksMore)
    }
}
