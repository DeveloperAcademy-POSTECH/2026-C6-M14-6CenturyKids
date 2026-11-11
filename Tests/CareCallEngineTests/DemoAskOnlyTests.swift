import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 시연: 처음 통화에서 고른 항목만 묻고 바로 '그 밖에'로 간다. 가상 발화만
@MainActor
struct DemoAskOnlyTests {
    let config: CareCallConfig
    let rules: EmergencyRules
    let mock = MockAnalyzer()

    init() throws {
        config = try fixture(CareCallConfig.self, "side_effects")
        rules = try fixture(EmergencyRules.self, "emergency_rules")
    }

    @Test func 고른_세_항목만_설정_순서대로_묻고_그_밖에로_간다() async {
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock,
                                   askOnly: ["stomatitis", "constipation", "dehydration_nutrition"])
        #expect(call.start().utterance == config.openingQuestion) // 처음 통화 첫 질문은 그대로
        var asked: [String] = []
        var out = await call.handle(patientText: "괜찮아요")
        while let key = out.phase.slotKey {
            asked.append(key)
            out = await call.handle(patientText: "없어요")
        }
        #expect(asked == ["constipation", "stomatitis", "dehydration_nutrition"])
        #expect(out.phase == .other)
        #expect(call.progress < 1)
        out = await call.handle(patientText: "없어요")
        #expect(out.phase == .saved)
    }

    @Test func 목데이터는_네_항목을_둘은_있음_둘은_없음으로_채우고_답한_증상은_덮지_않는다() throws {
        let plan = DemoCareCallPlan(effectIds: config.effects.map(\.id))
        #expect(plan.asked.count == 3 && plan.mocked.count == 4 && plan.mockPresent.count == 2)
        let patient = UUID()
        let answered = try SymptomEntry(id: UUID(), symptomType: .diarrhea, presence: .absent, bodyPart: nil, bodySide: nil,
                                        durationMinutes: nil, occurrenceCount: nil, detail: "아니요")
        let filled = plan.filling(SymptomRecord(id: UUID(), patientId: patient, recordedDate: .now, conditionText: nil, symptoms: [answered]))
        #expect(filled.symptoms.filter { $0.symptomType == .diarrhea }.count == 1)
        let mockedDiarrhea = plan.mocked.contains("diarrhea")
        #expect(filled.symptoms.count == 1 + 4 - (mockedDiarrhea ? 1 : 0))
    }
}
