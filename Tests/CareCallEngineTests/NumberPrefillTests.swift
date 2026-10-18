import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 증상이 있다고 한 말에 횟수·지속 시간이 분명히 들어 있으면 그 꼬리질문을 다시 묻지 않는다 (2026-10-17 실기기: "네 한 번 토했어요" 뒤
/// "구토는 하루에 몇 번…"을 또 물음). 가상 발화만
@MainActor
struct NumberPrefillTests {
    let config: CareCallConfig
    let rules: EmergencyRules
    let converter: SymptomRecordConverter
    let mock = MockAnalyzer()

    init() throws {
        config = try fixture(CareCallConfig.self, "side_effects")
        rules = try fixture(EmergencyRules.self, "emergency_rules")
        converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
    }

    private func entry(_ call: InterviewEngine, _ type: SymptomType) -> SymptomEntry? {
        converter.record(from: call.ledger, patientId: UUID(), date: Date()).symptoms.first { $0.symptomType == type }
    }

    @Test func 유무_질문에_횟수까지_말하면_횟수를_묻지_않는다() async {
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        _ = await call.handle(patientText: "괜찮아요")
        #expect(call.phase == .slot(key: "nausea_vomiting", step: .presence))
        let next = await call.handle(patientText: "네 한 번 토했어요")
        #expect(next.phase == .slot(key: "constipation", step: .presence)) // 구토 횟수를 건너뛴다
        #expect(entry(call, .nauseaVomiting)?.occurrenceCount == 1)
        #expect(entry(call, .nauseaVomiting)?.detail == "구토 횟수: 네 한 번 토했어요")
    }

    @Test func 첫_질문에_증상과_횟수를_말해도_묻지_않는다() async {
        mock.script["어제 두 번 토했어요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        let next = await call.handle(patientText: "어제 두 번 토했어요")
        #expect(next.phase == .slot(key: "constipation", step: .presence))
        #expect(entry(call, .nauseaVomiting)?.occurrenceCount == 2)
    }

    @Test func 지속_시간도_말했으면_묻지_않는다() async {
        mock.script["저린 게 한 30분씩 가요"] = .mentions(Mention(effectId: "neuropathy", presence: .present))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        let next = await call.handle(patientText: "저린 게 한 30분씩 가요")
        #expect(next.phase != .slot(key: "neuropathy", step: .detail)) // "얼마나 가나요?"를 건너뛴다 (부위는 차례가 오면 묻는다)
        #expect(call.ledger["neuropathy"]?.details.map(\.text) == ["저린 게 한 30분씩 가요"])
        #expect(entry(call, .numbness)?.durationMinutes == 30)
    }

    @Test(arguments: ["두 번 토하고 설사도 했어요", "두세 번 토했어요", "열 번 넘게 토했어요", "어제 토했어요"])
    func 숫자가_분명하지_않거나_어느_증상_것인지_모르면_지금처럼_묻는다(answer: String) async {
        mock.script[answer] = answer.contains("설사")
            ? .mentions(Mention(effectId: "nausea_vomiting", presence: .present), Mention(effectId: "diarrhea", presence: .present))
            : .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        let next = await call.handle(patientText: answer)
        #expect(next.phase == .slot(key: "nausea_vomiting", step: .detail))
        #expect(call.ledger["nausea_vomiting"]?.details.isEmpty == true)
    }

    @Test func 이미_있음인_증상을_다시_말할_때는_채우지_않는다() async {
        mock.script["어제 토했어요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        mock.script["아까 말한 대로 두 번이요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        _ = await call.handle(patientText: "어제 토했어요")
        #expect(call.phase == .slot(key: "nausea_vomiting", step: .detail))
        _ = await call.handle(patientText: "아까 말한 대로 두 번이요") // 횟수 질문의 답으로 한 번만 기록된다
        #expect(call.ledger["nausea_vomiting"]?.details.map(\.text) == ["아까 말한 대로 두 번이요"])
    }
}
