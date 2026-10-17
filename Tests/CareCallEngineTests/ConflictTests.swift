import Testing
@testable import ToDocFeatures

@MainActor
struct ConflictTests {
    @Test func 한_답에서_같은_증상이_있음_없음으로_함께_나오면_있음으로_기록하고_이어_묻는다() async throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let rules = try fixture(EmergencyRules.self, "emergency_rules")
        let mock = MockAnalyzer()
        let text = "어제 좀 토했어요, 그거 말고는 괜찮아요"
        // 2026-10-13 실기기 평가 S00 #3의 모델 출력
        mock.script[text] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present, quote: "어제 좀 토했어요"),
                                      Mention(effectId: "nausea_vomiting", presence: .absent, quote: "그거 말고는 괜찮아요"))
        let engine = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = engine.start()
        let out = await engine.handle(patientText: text)
        #expect(engine.ledger["nausea_vomiting"]?.presence == .present)
        #expect(engine.ledger["nausea_vomiting"]?.needsReview == false)
        #expect(out.phase == .slot(key: "nausea_vomiting", step: .detail))
    }

    @Test func 다른_증상의_없음은_그대로_받는다() async throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let rules = try fixture(EmergencyRules.self, "emergency_rules")
        let mock = MockAnalyzer()
        let text = "토했고 설사는 안 했어요"
        mock.script[text] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present, quote: "토했고"),
                                      Mention(effectId: "diarrhea", presence: .absent, quote: "설사는 안 했어요"))
        let engine = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = engine.start()
        _ = await engine.handle(patientText: text)
        #expect(engine.ledger["nausea_vomiting"]?.presence == .present)
        #expect(engine.ledger["diarrhea"]?.presence == .absent)
    }
}

@MainActor
struct MissedListSymptomTests {
    @Test func 첫_답에_목록_증상_낱말이_있는데_기록이_없으면_한_번_더_분석한다() async throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let rules = try fixture(EmergencyRules.self, "emergency_rules")
        let mock = MockAnalyzer()
        let text = "설사를 좀 했고 입안도 헐었어요"
        var calls = 0
        // 2026-10-13 실기기 평가 S02 #3: 첫 분석이 아무것도 기록하지 않음
        mock.respond = { request in
            guard request.patientText == text else { return nil }
            calls += 1
            return calls == 1 ? .empty : .mentions(Mention(effectId: "diarrhea", presence: .present, quote: "설사를 좀 했고"),
                                                    Mention(effectId: "stomatitis", presence: .present, quote: "입안도 헐었어요"))
        }
        let engine = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = engine.start()
        _ = await engine.handle(patientText: text)
        #expect(calls == 2)
        #expect(engine.ledger["diarrhea"]?.presence == .present)
        #expect(engine.ledger["stomatitis"]?.presence == .present)
    }
}

@MainActor
struct UngroundedConflictTests {
    @Test func 근거_없는_있음으로_근거_있는_없음을_지우지_않는다() async throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let rules = try fixture(EmergencyRules.self, "emergency_rules")
        let mock = MockAnalyzer()
        let text = "아니요, 안 토했어요"
        mock.respond = { request in
            guard request.patientText == text else { return nil }
            return .mentions(Mention(effectId: "nausea_vomiting", presence: .present, quote: "구토를 하시거나 속이 메스꺼우신"),
                             Mention(effectId: "nausea_vomiting", presence: .absent, quote: "안 토했어요"))
        }
        let engine = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = engine.start()
        _ = await engine.handle(patientText: "좋아요")
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .presence))
        _ = await engine.handle(patientText: text)
        #expect(engine.ledger["nausea_vomiting"]?.presence == .absent)
    }
}
