import Foundation
import Testing
@testable import ToDocCareCall

/// 모델이 고른 증상의 낱말은 없고 다른 증상 낱말만 있으면 그 증상으로 바꾸되, 한 글자 낱말("물", "먹", "토")은 근거로 쓰지 않는다.
/// "물을 마셔도 속이 안 좋아요"가 탈수·영양으로 바뀌었다 (2026-10-19 검토). 가상 발화만
@MainActor
struct KeywordReassignTests {
    let config: CareCallConfig
    let rules: EmergencyRules
    let mock = MockAnalyzer()

    init() throws {
        config = try fixture(CareCallConfig.self, "side_effects")
        rules = try fixture(EmergencyRules.self, "emergency_rules")
    }

    @Test(arguments: [("물을 마셔도 속이 안 좋아요", "nausea_vomiting"), ("토요일부터 입안이 좀 이상해요", "stomatitis"),
                      ("물도 잘 안 넘어가고 입이 좀 아파요", "dehydration_nutrition")])
    func 한_글자_낱말로는_모델이_고른_증상을_바꾸지_않는다(answer: String, picked: String) async {
        mock.script[answer] = .mentions(Mention(effectId: picked, presence: .present))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock, followUp: [])
        _ = call.start()
        _ = await call.handle(patientText: answer)
        #expect(call.ledger[picked]?.presence == .present) // "물"(식사)·"토"(구토)를 근거로 옮기지 않는다
        #expect(call.ledger.order.filter { call.ledger[$0]?.presence == .present } == [picked])
    }
}
