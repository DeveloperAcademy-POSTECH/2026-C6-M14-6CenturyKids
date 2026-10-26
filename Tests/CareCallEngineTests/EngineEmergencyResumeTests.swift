import Foundation
import Testing
@testable import ToDocCareCall

/// 응급 안내 뒤 환자가 기록을 이어 가기로 한 경우. 가상 발화만
@MainActor
struct EngineEmergencyResumeTests {
    let engine: InterviewEngine

    init() throws {
        engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                 rules: try fixture(EmergencyRules.self, "emergency_rules"), analyzer: MockAnalyzer())
    }

    @Test func 응급_뒤_이어_가면_응급_답을_받은_질문부터_다시_묻고_응급_말은_남긴다() async {
        _ = engine.start()
        _ = await engine.handle(patientText: "괜찮아요")
        let question = engine.lastQuestion
        let phase = engine.phase
        let out = await engine.handle(patientText: "어제부터 숨이 차고 열이 39도까지 났어요")
        #expect(out.phase == .emergencyEnded && !engine.canGoBack)

        let resumed = engine.continueAfterEmergency()
        #expect(resumed?.utterance == question && engine.phase == phase)
        #expect(engine.ledger.order.contains { $0.hasPrefix("other:") }) // 응급으로 남긴 말
        #expect(!engine.canGoBack) // 응급 전으로는 돌아가지 않는다
        #expect(engine.continueAfterEmergency() == nil)
        var next = InterviewEngine.Output(utterance: "", phase: engine.phase)
        for _ in 0..<40 where !next.isFinished { next = await engine.handle(patientText: "없어요") }
        #expect(next.phase == .saved)
    }
}
