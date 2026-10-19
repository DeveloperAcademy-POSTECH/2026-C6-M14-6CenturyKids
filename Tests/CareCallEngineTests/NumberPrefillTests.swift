import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 증상 유무 질문에 횟수·지속 시간까지 답하면 그 꼬리질문을 다시 묻지 않는다 (2026-10-17 실기기: "네 한 번 토했어요" 뒤
/// "구토는 하루에 몇 번…"을 또 물음). 숫자가 다른 일일 수 있으면 지금처럼 묻는다. 가상 발화만
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

    /// 컨디션에 답하고 key 증상의 유무 질문까지 (앞 증상은 "아니요")
    private func ask(_ key: String) async -> InterviewEngine {
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        _ = await call.handle(patientText: "괜찮아요")
        while call.phase != .slot(key: key, step: .presence) { _ = await call.handle(patientText: "아니요") }
        return call
    }

    @Test func 유무_질문에_횟수까지_말하면_횟수를_묻지_않는다() async {
        let call = await ask("nausea_vomiting")
        let next = await call.handle(patientText: "네 한 번 토했어요")
        #expect(next.phase == .slot(key: "constipation", step: .presence)) // 구토 횟수를 건너뛴다
        #expect(entry(call, .nauseaVomiting)?.occurrenceCount == 1)
        #expect(entry(call, .nauseaVomiting)?.detail == "구토 횟수: 네 한 번 토했어요")
    }

    @Test func 설사처럼_꼬리질문_낱말이_없으면_증상_낱말과_같은_절의_숫자만_채운다() async {
        let call = await ask("diarrhea")
        _ = await call.handle(patientText: "네 설사를 세 번 했어요")
        #expect(entry(call, .diarrhea)?.occurrenceCount == 3)
    }

    @Test func 유무_질문에_지속_시간까지_말하면_묻지_않고_부위를_묻는다() async {
        let call = await ask("neuropathy")
        let next = await call.handle(patientText: "네 한 30분씩 저려요")
        #expect(next.phase == .slot(key: "neuropathy", step: .location)) // "얼마나 가나요?"를 건너뛴다
        #expect(entry(call, .numbness)?.durationMinutes == 30)
    }

    @Test(arguments: [
        ("nausea_vomiting", "네 한 번이요"),            // 구토 낱말("토")이 없어 구토 횟수인지 모른다
        ("nausea_vomiting", "네 두세 번 토했어요"),      // 어림수
        ("nausea_vomiting", "네 열 번 넘게 토했어요"),   // 넘게
        ("neuropathy", "네 30분 전부터 저려요"),        // 시작 시점
        ("neuropathy", "네 아침부터 한 시간쯤 저려요"),  // 시작 시점이 섞임
        ("neuropathy", "네 30분 됐어요"),              // 시작 시점 ("됐")
        ("neuropathy", "네 손이 저려요, 30분"),        // 지속을 뜻하는 말이 없음
        ("diarrhea", "네, 약을 세 번 먹고 나서 그래요"),  // 설사 낱말이 없어 설사 횟수인지 모른다
        ("diarrhea", "네 설사 두 번, 약은 세 번 먹었어요"), // 다른 절에 다른 숫자
        ("nausea_vomiting", "네 한 번 토했어요, 그 전날은 두세 번"), // 문장 전체로는 어림수라 저장될 횟수가 없다
    ])
    func 숫자가_분명하지_않거나_그_꼬리질문의_답인지_모르면_묻는다(key: String, answer: String) async {
        let call = await ask(key)
        let next = await call.handle(patientText: answer)
        #expect(next.phase == .slot(key: key, step: .detail))
        #expect(call.ledger[key]?.details.isEmpty == true)
    }

    @Test(arguments: ["어제 두 번 토했어요", "약을 두 번 먹었는데 설사를 했어요"])
    func 첫_질문에서_말한_숫자는_다른_일일_수_있어_묻는다(answer: String) async {
        let key = answer.contains("설사") ? "diarrhea" : "nausea_vomiting"
        mock.script[answer] = .mentions(Mention(effectId: key, presence: .present))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        _ = await call.handle(patientText: answer)
        #expect(call.ledger[key]?.presence == .present)
        #expect(call.ledger[key]?.details.isEmpty == true) // 횟수는 그 질문을 할 때 묻는다
    }

    @Test func 다른_증상_질문_중에_말한_숫자는_채우지_않는다() async {
        let correction = "아, 그러고 보니 어제 한 번 토했어요"
        mock.respond = { req in
            req.patientText == correction ? .mentions(Mention(effectId: "nausea_vomiting", presence: .present, quote: correction)) : nil
        }
        let call = await ask("constipation")
        _ = await call.handle(patientText: correction)
        #expect(call.ledger["nausea_vomiting"]?.presence == .present)
        #expect(call.ledger["nausea_vomiting"]?.details.isEmpty == true)
    }
}
