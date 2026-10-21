import Foundation
import Testing
@testable import ToDocCareCall

/// P3 실기기에서 본 모델 출력 문제를 엔진이 막는지
@MainActor
struct EngineGuardTests {
    @Test(arguments: [
        ("설사는 없어요", "설사는 없어요", false),          // 환자 말 되풀이
        ("손이 저려요?", "네, 손이 좀 저려요", true),       // 일부만 겹침, 질문 형태 → 허용
        ("설사는 없어요?", "설사는 없어요", false),         // 물음표만 붙인 되풀이
        ("다른 부작용은 없다고 하셨습니다.", "다른 건 없어요", false), // 질문 아님
        ("조금 더 자세히 말씀해 주시겠어요?", "그냥 좀 그래요", true),
        ("입안이 헐거나 아픈 부위가 있으신가요? (예: 어느 부분, 얼마나 심한지 등)", "구내염이 좀 생긴 거 같긴 해요", false), // 괄호
        ("오심·구토에 대해 좀 더 말씀해주실 수 있으신가요? 예를 들어, 구토를 하셨는지 알려주세요.", "음 좀 어지러웠어요 속이", false), // 여러 문장
        ("구토를 하셨는지, 속이 메스꺼우셨는지, 얼마나 자주, 얼마나 오래 지속되었는지 말씀해 주시겠어요?", "속이 좀", false), // 너무 김
        ("피부에 발진이나 가려운 곳이 있으신가요?", "네 있어요. 너무 슬퍼요.", true),
    ])
    func 꼬리질문_검증(utterance: String, patient: String, accepted: Bool) {
        #expect((InterviewEngine.validFollowUp(utterance, patientText: patient) != nil) == accepted)
    }

    @Test func 환자_말이_아닌_근거의_언급은_기록하지_않는다() {
        var ledger = Ledger()
        let ids: Set = ["nausea_vomiting"]
        ledger.apply(Mention(effectId: "nausea_vomiting", presence: .present, quote: "오심·구토가 가장 심한 정도예요."),
                     patientText: "다른 건 없어요", knownEffectIds: ids)
        #expect(ledger["nausea_vomiting"] == nil)
        // 근거가 빈 '없음' (모델이 묻지 않은 항목을 채움) → 기록하지 않는다
        ledger.apply(Mention(effectId: "nausea_vomiting", presence: .absent, quote: ""),
                     patientText: "설사를 좀 했고 입안도 헐었어요", knownEffectIds: ids)
        #expect(ledger["nausea_vomiting"] == nil)
        ledger.apply(Mention(effectId: "nausea_vomiting", presence: .present, quote: "어제 좀 토했어요"),
                     patientText: "어제 좀 토했어요, 그거 말고는 괜찮아요", knownEffectIds: ids)
        #expect(ledger["nausea_vomiting"]?.presence == .present)
    }

    /// 2026-10-08 기기: 식사 질문에 "입이 아파서요" → 모델은 구내염만 기록, 식사를 세 번 되물음
    @Test(arguments: [("입이 아파서요.", true), ("음 입이 아파서 그렇다고요", true), ("입맛이 없어서요", true),
                      ("아니요 그냥 바빠서요", false), ("집에서요", false)])
    func 이유로_답하면_있음(answer: String, present: Bool) async throws {
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: ReasonOnlyAnalyzer())
        _ = engine.start()
        for _ in 0..<10 where engine.phase != .slot(key: "dehydration_nutrition", step: .presence) {
            _ = await engine.handle(patientText: "없어요")
        }
        #expect(engine.phase == .slot(key: "dehydration_nutrition", step: .presence))
        _ = await engine.handle(patientText: answer)
        #expect((engine.ledger["dehydration_nutrition"]?.presence == .present) == present)
        if present { #expect(engine.phase != .slot(key: "dehydration_nutrition", step: .presence)) } // 같은 질문 되풀이 안 함
    }

    /// 2026-10-08 기기: 식사 질문 뒤 구내염을 이름 없이 다시 물어 환자가 식사에 대한 답을 함
    @Test func 다른_항목으로_돌아가면_이름을_먼저_말한다() async throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let engine = InterviewEngine(config: config,
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: ReasonOnlyAnalyzer())
        _ = engine.start()
        for _ in 0..<10 where engine.phase != .slot(key: "dehydration_nutrition", step: .presence) {
            _ = await engine.handle(patientText: "없어요")
        }
        // 식사 질문 중 구내염이 새로 기록됨 → 구내염 시작 시점으로 돌아간다
        let out = await engine.handle(patientText: "입이 아파서요")
        #expect(engine.phase == .slot(key: "stomatitis", step: .detail))
        #expect(out.utterance.hasPrefix("입안이 헐거나 아픈 것에 대해 여쭤볼게요. "))
        // 구내염을 마치면 아까 묻던 식사(이유 답으로 있음)의 섭취량으로 돌아가며 다시 이름을 먼저 말한다
        let next = await engine.handle(patientText: "어제부터요")
        #expect(engine.phase == .slot(key: "dehydration_nutrition", step: .detail))
        #expect(next.utterance.contains("에 대해 여쭤볼게요"))
    }

    /// 2026-10-08 평가: 구토 질문의 답 "음 좀 어지러웠어요 속이"를 근거로 모델이 식사를 '없음'으로 채워 식사 질문이 빠짐
    @Test(arguments: [("음 좀 어지러웠어요 속이", false), ("속이 메스꺼워요, 식사는 평소랑 똑같이 해요", true)])
    func 묻지_않은_항목의_없음은_그_낱말이_있을_때만(answer: String, kept: Bool) async throws {
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: ScriptedAnalyzer { request in
                                         .mentions(Mention(effectId: "nausea_vomiting", presence: .present, quote: request.patientText),
                                                   Mention(effectId: "dehydration_nutrition", presence: .absent, quote: request.patientText))
                                     })
        _ = engine.start()
        _ = await engine.handle(patientText: "없어요")
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .presence))
        _ = await engine.handle(patientText: answer)
        #expect(engine.ledger["nausea_vomiting"]?.presence == .present)
        #expect((engine.ledger["dehydration_nutrition"]?.presence == .absent) == kept)
    }

    @Test func 질문에_증상_이름이_있으면_앞말을_붙이지_않는다() async throws {
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: ScriptedAnalyzer { request in
                                         .mentions(Mention(effectId: "diarrhea", presence: .present, quote: request.patientText))
                                     })
        _ = engine.start()
        for _ in 0..<10 where engine.phase != .slot(key: "dehydration_nutrition", step: .presence) {
            _ = await engine.handle(patientText: "없어요")
        }
        // 식사 질문 중 설사를 했다고 정정 → 설사 횟수로 돌아간다. 질문에 "설사"가 있어 "설사에 대해 여쭤볼게요"는 붙이지 않는다
        let out = await engine.handle(patientText: "아 그러고 보니 설사를 했어요")
        #expect(engine.phase == .slot(key: "diarrhea", step: .detail))
        #expect(out.utterance.hasSuffix("설사는 하루에 몇 번 정도 하셨나요?"))
        #expect(!out.utterance.contains("에 대해 여쭤볼게요"))
    }

    /// 2026-10-08 기기: '그 밖에' 답 "뭐 있더라 잠을 잠 못 잡니다."를 모델이 비우고(따라 하기만) 기록 없이 마무리됨
    /// "모르겠어요"는 기타 '모름' + 원문으로 남긴다 (VagueAnswerTests)
    @Test(arguments: [("뭐 있더라 잠을 잠 못 잡니다.", true), ("딱히 없는 것 같아요", false), ("아니 괜찮아", false)])
    func 그_밖에_부정이_아닌_답은_원문으로_기록(answer: String, recorded: Bool) async throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let engine = InterviewEngine(config: config,
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: ScriptedAnalyzer { request in
                                         TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                                                    emergencySignal: false, utterance: request.patientText)
                                     })
        _ = engine.start()
        for _ in 0..<10 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        #expect(engine.phase == .other)
        let out = await engine.handle(patientText: answer)
        let others = engine.ledger.order.filter { $0.hasPrefix("other:") }
        #expect(others.isEmpty != recorded)
        if recorded {
            #expect(engine.ledger[others[0]]?.needsReview == true)
            #expect(out.utterance == config.otherDetail.question) // 한 번 더 묻고 마무리
        }
    }

    /// 2026-10-08 사용자 결정: "모르겠어요"는 되묻지 않고 '모름'으로 기록하고 넘어간다 (모델 없이)
    @Test func 모르겠어요는_모름으로_기록하고_넘어간다() async throws {
        let analyzer = ScriptedAnalyzer { request in
            .mentions(Mention(effectId: request.slotKey ?? "nausea_vomiting", presence: .present, quote: request.patientText))
        }
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: analyzer)
        _ = engine.start()
        _ = await engine.handle(patientText: "괜찮아요")
        _ = await engine.handle(patientText: "네 토했어요")               // 구토 있음 (메스꺼움은 말하지 않음)
        _ = await engine.handle(patientText: "하루 두 번이요")             // 구토 횟수
        #expect(engine.phase == .slot(key: "constipation", step: .presence))
        #expect(engine.acknowledgement(for: "잘 모르겠어요") == nil)      // 모델 없이 처리 → 맞장구 없음
        _ = await engine.handle(patientText: "잘 모르겠어요")
        #expect(engine.ledger["constipation"]?.unknownSteps == [.presence])
        #expect(engine.ledger["constipation"]?.presence == .unclear)
        #expect(engine.ledger["constipation"]?.needsReview == true)
        #expect(engine.phase == .slot(key: "diarrhea", step: .presence))
        _ = await engine.handle(patientText: "글쎄요, 기억이 안 나요")
        #expect(engine.ledger["diarrhea"]?.presence == .unclear)
        #expect(engine.phase == .slot(key: "stomatitis", step: .presence))
        #expect(engine.ledgerSummary().contains("오심·구토: present, 구토 횟수 ‘하루 두 번이요’"))
        #expect(engine.ledgerSummary().contains("변비: 모름"))
    }

    @Test(arguments: ["잘 모르겠는데 3번쯤이요", "모르겠지만 좀 메스꺼웠어요", "모르겠어요, 없는 것 같아요"])
    func 모르겠다와_다른_말이_섞이면_모델이_본다(answer: String) async throws {
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: ScriptedAnalyzer { _ in .empty })
        _ = engine.start()
        _ = await engine.handle(patientText: "괜찮아요")
        #expect(engine.acknowledgement(for: answer) != nil) // 짧은 답 처리 아님 → 모델 호출
    }

    /// 모델 출력이 잘려 실패하면 같은 답을 한 번 더 분석한다 (되묻지 않음). 두 번 다 실패하면 지금처럼 되묻는다
    @Test(arguments: [(1, true), (2, false)])
    func 분석_실패는_한_번_다시_분석한다(failures: Int, answered: Bool) async throws {
        let analyzer = FlakyAnalyzer(failures: failures)
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: analyzer)
        _ = engine.start()
        _ = await engine.handle(patientText: "괜찮아요")
        let out = await engine.handle(patientText: "아침에 속이 좀 메슥거렸어요")
        #expect(analyzer.calls == 2)
        #expect((engine.ledger["nausea_vomiting"]?.presence == .present) == answered)
        #expect(out.utterance.contains("다시 한 번 여쭤볼게요") != answered)
    }
}

/// 처음 failures번은 형식 실패, 그다음은 지금 항목 '있음'
final class FlakyAnalyzer: CareCallAI {
    private let failures: Int
    private(set) var calls = 0
    init(failures: Int) { self.failures = failures }
    func analyze(_ request: AnalysisRequest) async throws -> TurnResult {
        calls += 1
        if calls <= failures { throw CocoaError(.coderReadCorrupt) }
        return .mentions(Mention(effectId: request.slotKey ?? "nausea_vomiting", presence: .present, quote: request.patientText))
    }
}

final class ScriptedAnalyzer: CareCallAI {
    let respond: (AnalysisRequest) -> TurnResult
    init(_ respond: @escaping (AnalysisRequest) -> TurnResult) { self.respond = respond }
    func analyze(_ request: AnalysisRequest) async throws -> TurnResult { respond(request) }
}

/// 이유 쪽 증상(구내염)만 기록하는 모델
final class ReasonOnlyAnalyzer: CareCallAI {
    func analyze(_ request: AnalysisRequest) async throws -> TurnResult {
        // 근거 없는 '없음'은 기록되지 않으므로 이유 답 판정을 막지 않아야 한다 (Mac 평가에서 본 출력)
        .mentions(Mention(effectId: "stomatitis", presence: .present, quote: request.patientText),
                  Mention(effectId: "dehydration_nutrition", presence: .absent, quote: ""))
    }
}

@MainActor
struct LedgerGuardTests {
    let ids: Set = ["nausea_vomiting", "constipation", "stomatitis"]

    @Test func 기록_변경_금지면_새_항목만_받는다() {
        var ledger = Ledger()
        ledger.apply(Mention(effectId: "nausea_vomiting", presence: .present, quote: "토했어요"), patientText: "토했어요", knownEffectIds: ids)
        ledger.apply(Mention(effectId: "nausea_vomiting", presence: .absent, quote: "없어요"), patientText: "없어요",
                     knownEffectIds: ids, mayChangeRecorded: false)
        #expect(ledger["nausea_vomiting"]?.presence == .present)
        ledger.apply(Mention(effectId: "constipation", presence: .absent, quote: "없어요"), patientText: "없어요",
                     knownEffectIds: ids, mayChangeRecorded: false)
        #expect(ledger["constipation"]?.presence == .absent)
    }

    @Test func 목록에_없는_ID는_증상_이름이_없으면_버린다() {
        var ledger = Ledger()
        ledger.apply(Mention(effectId: "stomatitis_detail", presence: .present, quote: "입안이 아파요"), patientText: "입안이 아파요", knownEffectIds: ids)
        #expect(ledger.order.isEmpty)
        ledger.apply(Mention(effectId: "headache", otherName: "두통", presence: .present, quote: "머리가 아파요"),
                     patientText: "머리가 아파요", knownEffectIds: ids)
        #expect(ledger["other:두통"]?.presence == .present)
    }
}

@MainActor
struct CrossSlotTests {
    @Test func 다른_항목_질문에_짧은_답이면_기존_기록을_뒤집지_않는다() async throws {
        let mock = MockAnalyzer()
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        mock.script["어제 토했어요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        // 모델 오류 흉내: 변비 질문의 "없어요"를 구토에도 붙임
        mock.script["없어요"] = .mentions(Mention(effectId: "constipation", presence: .absent),
                                         Mention(effectId: "nausea_vomiting", presence: .absent))
        _ = engine.start()
        _ = await engine.handle(patientText: "어제 토했어요")
        _ = await engine.handle(patientText: "한 번이요")  // 횟수
        #expect(engine.phase == .slot(key: "constipation", step: .presence))
        _ = await engine.handle(patientText: "없어요")
        #expect(engine.ledger["nausea_vomiting"]?.presence == .present)
        #expect(engine.ledger["constipation"]?.presence == .absent)
    }
}

@MainActor
struct NumberParserTests {
    @Test(arguments: [("아니요, 3번이요", Set([3])), ("한 6점 정도", Set([6])), ("열이 39도", Set<Int>()), ("7.5", Set<Int>())])
    func 답에_섞인_숫자를_찾는다(text: String, expected: Set<Int>) {
        #expect(NumberParser.numbers(in: text) == expected)
    }
}

@MainActor
struct QuickAnswerTests {
    @Test func 짧은_답은_모델_없이_기록한다() async throws {
        let mock = MockAnalyzer()
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        _ = engine.start()
        _ = await engine.handle(patientText: "없어요")          // 처음 질문
        _ = await engine.handle(patientText: "아니요.")         // 구토: 없음
        _ = await engine.handle(patientText: "네")              // 변비: 있음 → 시작
        #expect(engine.phase == .slot(key: "constipation", step: .detail))
        _ = await engine.handle(patientText: "그저께부터요")     // 시작: 모델 없이 그대로 기록
        #expect(engine.ledger["constipation"]?.details.map(\.text) == ["그저께부터요"])
        #expect(engine.phase == .slot(key: "diarrhea", step: .presence))
        #expect(mock.requests.isEmpty)
        #expect(engine.ledger["nausea_vomiting"]?.presence == .absent)
        #expect(engine.ledger["constipation"]?.presence == .present)
        // 분명한 '없음'은 모델 없이, 다른 증상이 섞이면 모델로
        _ = await engine.handle(patientText: "아니요, 설사 안 했어요")
        #expect(mock.requests.isEmpty)
        #expect(engine.ledger["diarrhea"]?.presence == .absent)
        _ = await engine.handle(patientText: "아니요, 근데 입안이 좀 헐었어요")
        #expect(mock.requests.count == 1)
        // '아니요'로 시작해도 뒤에서 번복하면 모델로
        _ = await engine.handle(patientText: "아니요 저림 맞아요 저려요")
        #expect(mock.requests.count == 2)
    }
}

/// 응급 키워드 부정 처리. 애매하면 응급 쪽으로 (가상 문장)
@MainActor
struct KeywordMatcherTests {
    @Test(arguments: [
        ("열은 없고 숨이 차지도 않아요", false),
        ("숨이 차진 않아요", false),
        ("고열은 없었어요", false),
        ("호흡곤란은 아니에요", false),
        ("손주들 봐주느라 정신이 없었어요", false),
        ("숨이 차요", true),
        ("숨이 차서 잠을 잘 수가 없어요", true),         // 부정이 키워드에 붙지 않음
        ("숨이 차지 않은 건 아니에요", true),            // 이중 부정
        ("숨이 차진 않은데 가슴이 아파요", true),        // 다른 절의 응급
        ("숨이 차요, 열은 없어요", true),
        ("어젯밤부터 가슴이 쥐어짜듯이 아파요", true),
        ("소변이 안 나와요", true),
        ("아, 그리고 열이 조금 나요", false),           // 낱말 경계를 넘는 "고 열" ≠ 고열
        ("고열이 나요", true),
        ("숨이차요", true),                             // 키워드 안 공백은 붙여 써도 같음
        ("호흡 곤란이 있어요", true),
        ("호흡곤란이 있어요", true),
        ("조금만 걸어도 숨이 가빠서 계단을 못 올라가요", true), // 키워드 밖이던 표현 (확인용 H08)
        ("숨이 가쁘고 답답해요", true),
        ("숨 쉬기가 힘들어요", true),
        ("숨쉬기가 버거워요", true),
        ("숨이 막혀요", true),
        ("숨이 가쁘진 않아요", false),
    ])
    func 부정과_문맥(text: String, emergency: Bool) throws {
        let rules = try fixture(EmergencyRules.self, "emergency_rules")
        #expect((KeywordMatcher(keywords: rules.keywords).matches(text) != nil) == emergency)
    }
}

@MainActor
struct CorrectionRecheckTests {
    @Test func 다른_항목_질문중_번복을_모델이_놓치면_그_항목으로_다시_묻는다() async throws {
        let mock = MockAnalyzer()
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        let correction = "아, 그러고 보니 어제 한 번 토했어요"
        mock.respond = { req in
            guard req.patientText == correction else { return nil }
            // 모델 놓침 흉내: 변비 질문으로는 아무것도 뽑지 않고, 구토 질문으로 다시 물으면 뽑는다
            return req.slotKey == "nausea_vomiting" ? .mentions(Mention(effectId: "nausea_vomiting", presence: .present, quote: correction)) : .empty
        }
        mock.script["토하진 않았어요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .absent, quote: "토하진 않았어요"))
        _ = engine.start()
        _ = await engine.handle(patientText: "괜찮아요")
        _ = await engine.handle(patientText: "토하진 않았어요")
        #expect(engine.ledger["nausea_vomiting"]?.presence == .absent)
        // 변비 질문 중 번복. 모의 모델은 현재 항목(변비) 기준으로만 뽑으므로 첫 호출은 구토를 놓친다
        _ = await engine.handle(patientText: correction)
        #expect(engine.ledger["nausea_vomiting"]?.presence == .present)
        #expect(mock.requests.last?.slotKey == "nausea_vomiting")
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .detail))
    }
}

/// 기타 증상 누락 (P5 음성 테스트 "열이 조금 나요")
@MainActor
struct OtherSymptomTests {
    @Test func 이름_없는_기타는_발화_하나로_합치고_목록_질문_중이면_버린다() async throws {
        let mock = MockAnalyzer()
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        // 모델 흉내: 낱말로 쪼갠 이름 없는 기타 + 목록 밖 ID + 환자가 하지 않은 이름
        mock.script["열이 조금 나요"] = .mentions(Mention(effectId: "other", presence: .present, quote: "열"),
                                             Mention(effectId: "other", presence: .present, quote: "조금"),
                                             Mention(effectId: "fever", otherName: "피로", presence: .present, quote: "열이 조금 나요"))
        mock.script["네"] = .mentions(Mention(effectId: "other", otherName: "피로", presence: .present, quote: "네"))
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        _ = await engine.handle(patientText: "열이 조금 나요")
        let others = engine.ledger.order.filter { $0.hasPrefix("other:") }
        #expect(others == ["other:열이 조금 나요"])
        #expect(engine.phase == .other)
        _ = await engine.handle(patientText: "네") // 꼬리질문의 답은 모델 없이 그 항목의 내용으로 (새 기타를 만들지 않음)
        #expect(engine.ledger.order.filter { $0.hasPrefix("other:") } == ["other:열이 조금 나요"])
        #expect(engine.ledger["other:열이 조금 나요"]?.details.map(\.text) == ["네"])
        #expect(engine.phase == .saved)
    }

}

@MainActor
struct OtherSymptomRetryTests {
    @Test func 그_밖에_질문에_네만_답하면_무엇인지_되묻는다() async throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let mock = MockAnalyzer()
        let engine = InterviewEngine(config: config,
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        let calls = mock.requests.count
        let out = await engine.handle(patientText: "네")
        #expect(out.utterance == config.otherFollowUp)
        #expect(engine.phase == .other)
        #expect(mock.requests.count == calls) // 모델 호출 없음
        #expect(engine.ledger.order.allSatisfy { !$0.hasPrefix("other:") })
    }

    @Test func 그_밖에_분석이_실패해도_부정이_아니면_원문으로_기록하고_내용을_묻는다() async throws {
        let mock = MockAnalyzer()
        mock.failOn = ["잠을 잠 못 잡니다", "딱히 없는 것 같아요"]
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        // 음성 인식이 뭉갠 답처럼 증상 낱말이 없어도 부정이 아니면 원문 그대로 기록 (2026-10-08 기기).
        // "그게 좀 그래요" 같은 애매한 답은 기록하지 않는다 (VagueAnswerTests)
        let out = await engine.handle(patientText: "잠을 잠 못 잡니다")
        #expect(engine.ledger["other:잠을 잠 못 잡니다"]?.presence == .present)
        #expect(out.utterance == engine.config.otherDetail.question)
    }

    @Test(arguments: ["딱히 없는 것 같아요", "읎심더"])
    func 그_밖에_분석이_실패해도_부정이면_기록하지_않는다(answer: String) async throws {
        let mock = MockAnalyzer()
        mock.failOn = [answer]
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        _ = await engine.handle(patientText: answer)
        #expect(!engine.ledger.entries.keys.contains { $0.hasPrefix("other:") })
    }

    @Test(arguments: [
        ("네, 열이 조금 나신다고 하셨습니다.", true),
        ("조금 더 자세히 말씀해 주시겠어요?", false),   // 꼬리질문
        ("", false),
        ("열이 조금 나요.", false),                     // 환자 말 그대로 따라 씀
    ])
    func 맞장구만_쓴_답(utterance: String, retry: Bool) {
        let r = TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false, emergencySignal: false, utterance: utterance)
        #expect(InterviewEngine.acknowledgedWithoutRecord(r, during: .other, patientText: "열이 조금 나요") == retry)
        #expect(!InterviewEngine.acknowledgedWithoutRecord(r, during: .slot(key: "diarrhea", step: .presence), patientText: "열이 조금 나요"))
    }
}

@MainActor
struct SymptomHintTests {
    @Test(arguments: [
        ("어제부터 머리가 좀 아파요", true),
        ("별일 없었어요", false),
        ("기침이 나요", true),
    ])
    func 증상_표현이_있는데_기록이_없으면_재분석(text: String, retry: Bool) {
        let empty = TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false, emergencySignal: false, utterance: "")
        let hints = ["아파", "기침"]
        #expect(InterviewEngine.missedSymptomHint(empty, during: .opening, patientText: text, hints: hints) == retry)
        #expect(!InterviewEngine.missedSymptomHint(empty, during: .slot(key: "diarrhea", step: .presence), patientText: text, hints: hints))
    }
}

@MainActor
struct VerbatimOtherTests {
    @Test func 모델이_끝내_비우면_증상_표현이_있는_답을_원문으로_기록하고_검토_필요() async throws {
        let mock = MockAnalyzer()
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        mock.script["요즘 잠을 잘 못 자요"] = .empty
        mock.script["아픈 데는 없어요"] = .empty
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        _ = await engine.handle(patientText: "요즘 잠을 잘 못 자요")
        #expect(engine.ledger["other:요즘 잠을 잘 못 자요"]?.presence == .present)
        #expect(engine.ledger["other:요즘 잠을 잘 못 자요"]?.needsReview == true)
        #expect(mock.requests.filter { $0.patientText == "요즘 잠을 잘 못 자요" }.count == 2) // 한 번 더 분석
    }

    @Test func 모델이_기존_없음을_다시_내도_기록이_그대로면_원문으로_기록() async throws {
        let mock = MockAnalyzer()
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        let added = "아, 그리고 열이 조금 나요"
        mock.script[added] = .mentions(Mention(effectId: "dehydration_nutrition", presence: .absent, quote: added))
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        _ = await engine.handle(patientText: added)
        #expect(engine.ledger["other:아, 그리고 열이 조금 나요"] != nil)
    }

    @Test func 모델이_엉뚱한_항목에_붙여_막혀도_원문으로_기록() async throws {
        let mock = MockAnalyzer()
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        mock.script["열이 조금 나요"] = .mentions(Mention(effectId: "dehydration_nutrition", presence: .present))
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        _ = await engine.handle(patientText: "열이 조금 나요")
        #expect(engine.ledger["dehydration_nutrition"]?.presence == .absent)
        #expect(engine.ledger["other:열이 조금 나요"]?.needsReview == true)
    }

    @Test func 부정이면_기록하지_않는다() async throws {
        let mock = MockAnalyzer()
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        mock.script["아픈 데는 없어요"] = .empty
        mock.script["안 아파요"] = .empty
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        _ = await engine.handle(patientText: "안 아파요")
        #expect(engine.ledger.order.allSatisfy { !$0.hasPrefix("other:") })
    }
}

@MainActor
struct SymptomHintMatcherTests {
    @Test(arguments: [
        ("열이 조금 나요", true),
        ("요즘 잠을 잘 못 자요", true),
        ("열은 없고 숨이 차지도 않아요", false),
        ("열이 안 나요", false),
        ("안 아파요", false),
        ("머리가 좀 아파요", true),
    ])
    func 증상_표현_판별(text: String, hit: Bool) throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        #expect((KeywordMatcher(keywords: config.symptomHints, prefixNegation: true).matches(text) != nil) == hit)
    }
}

/// 일상 말투·군말 (2026-10-07 실기기 대화: "응 어 있어", "어 아니요", "맞게 정리 됐어"가 모델로 가 4~9초)
@MainActor
struct CasualAnswerTests {
    static let fillers = ["어", "음", "응", "아", "나"]

    @Test(arguments: [
        ("음 아프지 않아", "아프지 않아"),
        ("아프지않아", "아프지않아"),        // 낱말 안의 '아'는 떼지 않는다
        ("음식을 먹었어", "음식을 먹었어"),   // 낱말 안의 '음'은 떼지 않는다
        ("응 어 있어", "있어"),
        ("어, 아니요", "아니요"),
        ("응", "응"),                         // 남는 낱말이 없으면 그대로
        ("아 아파요", "아파요"),
    ])
    func 군말은_낱말_단위로만_뗀다(text: String, expected: String) {
        #expect(InterviewEngine.withoutFillers(text, fillers: Self.fillers) == expected)
    }

    private func makeEngine(_ mock: MockAnalyzer) throws -> InterviewEngine {
        InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                        rules: try fixture(EmergencyRules.self, "emergency_rules"), analyzer: mock)
    }

    @Test func 일상_말투_유무_답은_모델_없이() async throws {
        let mock = MockAnalyzer()
        let engine = try makeEngine(mock)
        _ = engine.start()
        _ = await engine.handle(patientText: "괜찮아요")
        _ = await engine.handle(patientText: "어 아니요")              // 구토
        _ = await engine.handle(patientText: "아니 딱히 피곤하진 않아")  // 변비
        _ = await engine.handle(patientText: "음 아프지 않아")          // 설사
        _ = await engine.handle(patientText: "응 어 있어")              // 구내염
        #expect(mock.requests.isEmpty)
        #expect(engine.ledger["nausea_vomiting"]?.presence == .absent)
        #expect(engine.ledger["constipation"]?.presence == .absent)
        #expect(engine.ledger["diarrhea"]?.presence == .absent)
        #expect(engine.ledger["stomatitis"]?.presence == .present)
    }

    @Test func 그_밖에_어_있어는_되묻고_없다고_하면_마무리() async throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let mock = MockAnalyzer()
        let engine = try makeEngine(mock)
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        let out = await engine.handle(patientText: "어 있어")
        #expect(out.utterance == config.otherFollowUp)
        _ = await engine.handle(patientText: "없어요")
        #expect(engine.phase == .saved)
        #expect(mock.requests.isEmpty)
    }
}

@MainActor
struct OpeningFollowUpTests {
    private func makeEngine(_ mock: MockAnalyzer) throws -> (InterviewEngine, CareCallConfig) {
        let config = try fixture(CareCallConfig.self, "side_effects")
        return (InterviewEngine(config: config, rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                analyzer: mock), config)
    }

    @Test(arguments: ["좋아요", "보통이에요", "그럭저럭이요", "요즘 잠은 잘 자요", "나쁘지 않아요"])
    func 문제없는_답은_되묻지_않는다(answer: String) async throws {
        let (engine, config) = try makeEngine(MockAnalyzer())
        _ = engine.start()
        let out = await engine.handle(patientText: answer)
        #expect(out.utterance == config.openingTransition.fine + " " + config.effects[0].ask)
    }

    @Test func 좋아요는_모델_없이() async throws {
        let mock = MockAnalyzer()
        let (engine, _) = try makeEngine(mock)
        _ = engine.start()
        _ = await engine.handle(patientText: "컨디션 좋아요")
        #expect(mock.requests.isEmpty)
    }

    @Test(arguments: ["나 컨디션 좀 피곤해요", "그저 그래요", "별로 안 좋아요", "좋긴 한데 좀 힘들어요"])
    func 컨디션_문제는_한_번_되묻는다(answer: String) async throws {
        let (engine, config) = try makeEngine(MockAnalyzer())
        _ = engine.start()
        let out = await engine.handle(patientText: answer)
        #expect(out.utterance == config.openingFollowUp)
        #expect(engine.phase == .opening)
        let next = await engine.handle(patientText: "그냥 그래요") // 두 번째는 되묻지 않음
        #expect(next.utterance == config.openingTransition.afterFollowUp + " " + config.effects[0].ask)
    }

    @Test func 되묻기_답까지_기록이_없으면_두_답을_합쳐_원문으로() async throws {
        let (engine, _) = try makeEngine(MockAnalyzer())
        _ = engine.start()
        _ = await engine.handle(patientText: "피곤해요")
        _ = await engine.handle(patientText: "일을 많이 해서요")
        #expect(engine.ledger["other:피곤해요 / 일을 많이 해서요"]?.needsReview == true)
    }

    @Test func 꼬리질문_답의_이름_없는_기타는_첫_답_기타에_붙인다() async throws {
        let mock = MockAnalyzer()
        mock.script["어제부터 머리가 좀 아파요"] = .mentions(Mention(effectId: "headache", presence: .present))
        mock.script["어제부터 계속 그래요"] = .mentions(Mention(effectId: "headache", presence: .present))
        let (engine, _) = try makeEngine(mock)
        _ = engine.start()
        _ = await engine.handle(patientText: "어제부터 머리가 좀 아파요")
        _ = await engine.handle(patientText: "어제부터 계속 그래요")
        #expect(engine.ledger.order.filter { $0.hasPrefix("other:") } == ["other:어제부터 머리가 좀 아파요"])
    }

    @Test func 목록_증상이_기록되면_되묻지_않는다() async throws {
        let mock = MockAnalyzer()
        mock.script["어제 토해서 힘들었어요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        let (engine, config) = try makeEngine(mock)
        _ = engine.start()
        let out = await engine.handle(patientText: "어제 토해서 힘들었어요")
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .detail))
        #expect(out.utterance.hasPrefix(config.openingTransition.noted))
    }
}

/// 횟수·시작 시점·지속 시간·섭취량 질문 (환자 말 그대로 기록)
@MainActor
struct DetailStepTests {
    @Test func 탈수_영양은_섭취량을_묻고_다음으로_넘어간다() async throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let mock = MockAnalyzer()
        let engine = InterviewEngine(config: config, rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: mock)
        _ = engine.start()
        for _ in 0..<20 where engine.phase != .slot(key: "dehydration_nutrition", step: .presence) {
            _ = await engine.handle(patientText: "없어요")
        }
        let q = await engine.handle(patientText: "네")
        #expect(q.utterance == config.effects.first { $0.id == "dehydration_nutrition" }?.details.first?.question)
        let next = await engine.handle(patientText: "평소의 반 정도요")
        #expect(engine.ledger["dehydration_nutrition"]?.details.map(\.text) == ["평소의 반 정도요"])
        #expect(next.phase == .other)
        _ = await engine.handle(patientText: "없어요")
        #expect(engine.phase == .saved)
        #expect(engine.ledgerSummary().contains("평소의 반 정도요"))
        #expect(mock.requests.isEmpty)
    }
}

@MainActor
struct FeverRuleTests {
    @Test(arguments: [
        ("열이 조금 나요", false), ("미열이 있어요", false), ("37.5도예요", false), ("체온이 37도", false),
        ("38도예요", true), ("열이 38.5도까지 올랐어요", true), ("열이 39", true), ("체온 40도", true), ("고열이 나요", false),
    ])
    func 체온_38도_이상만(text: String, emergency: Bool) throws {
        let rules = try fixture(EmergencyRules.self, "emergency_rules")
        #expect(rules.mentionsFever(text) == emergency)
    }

    @Test func 열이_조금은_응급으로_끝내지_않는다() async throws {
        let engine = InterviewEngine(config: try fixture(CareCallConfig.self, "side_effects"),
                                     rules: try fixture(EmergencyRules.self, "emergency_rules"),
                                     analyzer: MockAnalyzer())
        _ = engine.start()
        _ = await engine.handle(patientText: "열이 조금 나요")
        #expect(engine.phase != .emergencyEnded)
        _ = await engine.handle(patientText: "재 보니까 38.2도예요")
        #expect(engine.phase == .emergencyEnded)
    }
}


/// 2026-10-19 실기기: '그 밖에'에 "잘 모르겠는데 머리가 아파요" → 모델이 되묻고, 다음 답 "없어요"로 두통이 사라짐
@MainActor
struct OtherClarificationTests {
    @Test func 그_밖에_증상_표현이_있으면_모델이_되물어도_원문을_남기고_내용을_묻는다() async throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let mock = MockAnalyzer()
        mock.script["잘 모르겠는데 머리가 아파요"] = TurnResult(mentions: [], answeredCurrentSlot: false, needsClarification: true,
                                                         emergencySignal: false, utterance: "어디가 아프신지 조금 더 말씀해 주시겠어요?")
        let engine = InterviewEngine(config: config, rules: try fixture(EmergencyRules.self, "emergency_rules"), analyzer: mock)
        _ = engine.start()
        for _ in 0..<10 where engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        let out = await engine.handle(patientText: "잘 모르겠는데 머리가 아파요")
        let others = engine.ledger.order.compactMap { engine.ledger[$0] }.filter { $0.effectId == "other" }
        #expect(others.count == 1 && others[0].presence == .present && others[0].needsReview)
        #expect(out.utterance == config.otherDetail.question)
        _ = await engine.handle(patientText: "없어요")
        #expect(engine.ledger.order.compactMap { engine.ledger[$0] }.contains { $0.effectId == "other" && $0.presence == .present })
    }
}

/// 2026-10-19 실기기: 첫 답 "요즘 입맛이 좀 없어요" → 모델이 식사를 '없음'으로 기록하고 식사 질문을 건너뜀
@MainActor
struct PresentPhraseTests {
    let config = try! fixture(CareCallConfig.self, "side_effects")
    let rules = try! fixture(EmergencyRules.self, "emergency_rules")

    @Test(arguments: ["요즘 입맛이 좀 없어요", "입맛이 없어졌어요"])
    func 첫_답의_입맛이_없어요는_모델이_없음이라_해도_식사_있음(answer: String) async {
        let mock = MockAnalyzer()
        mock.script[answer] = .mentions(Mention(effectId: "dehydration_nutrition", presence: .absent))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock, followUp: answer.contains("졌") ? [] : nil)
        _ = call.start()
        _ = await call.handle(patientText: answer)
        #expect(call.ledger["dehydration_nutrition"]?.presence == .present)
    }

    /// 2026-10-20 Mac 평가 H16: 구토 답에 지난 식사 이야기가 섞이면 식사를 '있음'으로 넣어 식사 질문을 건너뛰었다
    @Test func 다른_항목_답의_식사_말은_식사_질문을_건너뛰게_하지_않는다() async {
        let answer = "이틀 동안은 계속 메슥거려서 밥을 거의 못 먹었는데 지금은 좀 나아졌어요"
        let mock = MockAnalyzer()
        mock.script[answer] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        _ = await call.handle(patientText: "괜찮아요")
        #expect(call.phase == .slot(key: "nausea_vomiting", step: .presence))
        _ = await call.handle(patientText: answer)
        #expect(call.ledger["dehydration_nutrition"] == nil)
        while call.phase != .other, call.phase != .slot(key: "dehydration_nutrition", step: .presence) {
            _ = await call.handle(patientText: call.phase.slotKey == "nausea_vomiting" ? "어제부터요" : "아니요")
        }
        #expect(call.phase == .slot(key: "dehydration_nutrition", step: .presence))
    }

    @Test(arguments: ["약을 못 먹었어요", "약을 잘 못 먹어요", "식사 후에 약을 못 먹었어요", "약을 밥이랑 같이 못 먹었어요", "밥 먹고 못 걸었어요"])
    func 약을_못_먹었다는_말은_식사_증상이_아니다(answer: String) async {
        let call = InterviewEngine(config: config, rules: rules, analyzer: MockAnalyzer())
        _ = call.start()
        _ = await call.handle(patientText: answer)
        #expect(call.ledger["dehydration_nutrition"]?.presence != .present)
    }

    @Test(arguments: ["입맛이 떨어졌어요", "식욕이 떨어졌어요", "먹기가 싫어요", "먹고 싶지 않아요", "반도 못 먹었어요",
                      "조금밖에 못 먹어요", "물도 못 마셔요", "물을 잘 안 마셔요", "약을 먹고 나서 입맛이 없어요", "약간 입맛이 없어요"])
    func 첫_답의_식사_증상_말은_모델이_없음이라_해도_식사_있음(answer: String) async {
        let mock = MockAnalyzer()
        mock.script[answer] = .mentions(Mention(effectId: "dehydration_nutrition", presence: .absent))
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        _ = await call.handle(patientText: answer)
        #expect(call.ledger["dehydration_nutrition"]?.presence == .present)
    }

    @Test(arguments: [("입맛이 없어요", MentionPresence.present), ("밥이 잘 안 넘어가요", .present), ("요즘 밥을 잘 못 먹어요", .present),
                      ("입맛 없는 건 아니에요", .absent), ("밥을 못 먹은 건 아니에요", .absent), ("아니요 잘 먹어요", .absent)])
    func 식사_질문의_답(answer: String, expected: MentionPresence) async {
        let mock = MockAnalyzer()
        for negative in ["입맛 없는 건 아니에요", "밥을 못 먹은 건 아니에요"] {
            mock.script[negative] = .mentions(Mention(effectId: "dehydration_nutrition", presence: .absent))
        }
        let call = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = call.start()
        _ = await call.handle(patientText: "괜찮아요")
        while call.phase != .slot(key: "dehydration_nutrition", step: .presence) { _ = await call.handle(patientText: "아니요") }
        _ = await call.handle(patientText: answer)
        #expect(call.ledger["dehydration_nutrition"]?.presence == expected) // "입맛이 없어요"는 '없어요'로 끝나도 바로 '없음'이 아니다
    }
}
