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
        // 대화에서 다룬 항목은 기록에 없어도 목데이터로 채우지 않는다
        let touched = plan.filling(SymptomRecord(id: UUID(), patientId: patient, recordedDate: .now, conditionText: nil, symptoms: []),
                                   touched: Set(plan.mocked))
        #expect(touched.symptoms.isEmpty)
    }

    @Test func 대화를_넘기면_묻지_못한_항목까지_모두_채우고_답한_증상과_컨디션은_그대로_둔다() throws {
        let ids = config.effects.map(\.id)
        let plan = DemoCareCallPlan(effectIds: ids)
        let answered = try SymptomEntry(id: UUID(), symptomType: .diarrhea, presence: .present, bodyPart: nil, bodySide: nil,
                                        durationMinutes: nil, occurrenceCount: 5, detail: "다섯 번이요")
        func record(condition: String?, _ symptoms: [SymptomEntry]) -> SymptomRecord {
            SymptomRecord(id: UUID(), patientId: UUID(), recordedDate: .now, conditionText: condition, symptoms: symptoms)
        }
        let filled = plan.fillingAll(record(condition: "그럭저럭이요", [answered]), of: ids, fillsCondition: true)
        #expect(Set(filled.symptoms.map(\.symptomType)).count == 7 && filled.symptoms.count == 7)
        #expect(filled.symptoms.first { $0.symptomType == .diarrhea }?.id == answered.id)
        #expect(filled.conditionText == "그럭저럭이요")
        // 첫 질문에 답하기 전에 넘기면 컨디션도 채운다. 있음은 처음에 정한 두 항목뿐
        let empty = plan.fillingAll(record(condition: nil, []), of: ids, fillsCondition: true)
        #expect(empty.symptoms.count == 7 && empty.symptoms.filter { $0.presence == .present }.count == 2)
        #expect(empty.conditionText?.isEmpty == false)
        // 다시 거는 통화는 그날 기록에 없는 항목만 채우고 컨디션은 두지 않는다
        let followUp = plan.fillingAll(record(condition: nil, []), of: ["diarrhea"], fillsCondition: false)
        #expect(followUp.symptoms.map(\.symptomType) == [.diarrhea] && followUp.conditionText == nil)
    }
}
