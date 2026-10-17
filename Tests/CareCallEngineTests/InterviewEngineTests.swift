import Foundation
import Testing
@testable import ToDocFeatures

/// 가상 발화만 사용. 실제 환자 정보 없음.
/// 모델 대신 규칙으로 답하는 Mock. `script`에 발화별 결과를 넣으면 그것을, 없으면 기본 규칙을 쓴다.
final class MockAnalyzer: CareCallAI {
    var script: [String: TurnResult] = [:]
    var failOn: Set<String> = []
    /// 요청(질문 항목 포함)에 따라 답을 바꿀 때
    var respond: ((AnalysisRequest) -> TurnResult?)?
    private(set) var requests: [AnalysisRequest] = []

    func analyze(_ request: AnalysisRequest) async throws -> TurnResult {
        requests.append(request)
        if failOn.contains(request.patientText) { throw CancellationError() }
        if var scripted = respond?(request) ?? script[request.patientText] {
            // 대본에서 근거를 생략하면 환자 말 전체를 근거로 (실제 모델은 근거를 써야 기록된다)
            for i in scripted.mentions.indices where scripted.mentions[i].quote.isEmpty { scripted.mentions[i].quote = request.patientText }
            return scripted
        }
        guard let key = request.slotKey, request.step == .presence else { return .empty }
        let text = request.patientText
        let presence: MentionPresence = text.contains("없") || text.contains("아니") || text.contains("괜찮") ? .absent
            : text.contains("네") || text.contains("있") ? .present : .unclear
        let id = key.hasPrefix("other:") ? "other" : key
        return TurnResult(mentions: [Mention(effectId: id, presence: presence, locations: [], quote: text)],
                          answeredCurrentSlot: presence != .unclear, needsClarification: presence == .unclear,
                          emergencySignal: false, utterance: presence == .unclear ? "조금 더 자세히 말씀해 주시겠어요?" : "")
    }

}

extension TurnResult {
    static let empty = TurnResult(mentions: [], answeredCurrentSlot: false, needsClarification: false,
                                  emergencySignal: false, utterance: "")
    static func mentions(_ m: Mention...) -> TurnResult {
        TurnResult(mentions: m, answeredCurrentSlot: true, needsClarification: false, emergencySignal: false, utterance: "")
    }
}

@MainActor
struct InterviewEngineTests {
    let config: CareCallConfig
    let rules: EmergencyRules
    let mock = MockAnalyzer()
    let engine: InterviewEngine

    init() throws {
        config = try fixture(CareCallConfig.self, "side_effects")
        rules = try fixture(EmergencyRules.self, "emergency_rules")
        engine = InterviewEngine(config: config, rules: rules, analyzer: mock)
    }

    /// 나머지 항목에 모두 "없어요"로 답해 저장까지 진행
    private func answerNoToRest() async -> InterviewEngine.Output {
        var out = InterviewEngine.Output(utterance: "", phase: engine.phase)
        for _ in 0..<40 where !out.isFinished {
            out = await engine.handle(patientText: "없어요")
        }
        return out
    }

    @Test func 먼저_언급된_부작용은_유무를_건너뛰고_횟수만_묻는다() async {
        mock.script["어제 좀 토했어요, 그거 말고는 괜찮아요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        _ = engine.start()

        let out = await engine.handle(patientText: "어제 좀 토했어요, 그거 말고는 괜찮아요")
        #expect(out.phase == .slot(key: "nausea_vomiting", step: .detail))
        #expect(out.utterance == config.openingTransition.noted + " " + config.effects[0].details[0].question)

        let next = await engine.handle(patientText: "한 번이요")
        #expect(engine.ledger["nausea_vomiting"]?.details.map(\.text) == ["한 번이요"])
        #expect(next.phase == .slot(key: "constipation", step: .presence))
        #expect(!engine.ledger["nausea_vomiting"]!.askedSteps.contains(.presence))
    }

    @Test(arguments: [
        ("네 토했어요", ["구토 횟수"]),
        ("네 속이 메스꺼워요", ["메스꺼움 시작"]),
        ("네", ["구토 횟수", "메스꺼움 시작"]), // 어느 쪽인지 말하지 않으면 둘 다
        ("네 메스꺼웠는데 토하진 않았어요", ["메스꺼움 시작"]),
    ])
    func 구토는_횟수_메스꺼움은_시작을_묻는다(answer: String, labels: [String]) async {
        _ = engine.start()
        _ = await engine.handle(patientText: "없어요") // 첫 질문
        var out = await engine.handle(patientText: answer)
        var asked: [String] = []
        while out.phase == .slot(key: "nausea_vomiting", step: .detail) {
            asked.append(out.utterance)
            out = await engine.handle(patientText: "어제부터 두 번이요")
        }
        let questions = config.effects[0].details
        #expect(asked == labels.map { label in questions.first { $0.label == label }!.question })
        #expect(engine.ledger["nausea_vomiting"]?.details.map(\.label) == labels)
        #expect(engine.ledger["nausea_vomiting"]?.followUps == 0) // 두 번째 꼬리질문은 되묻기가 아니다
        #expect(out.phase == .slot(key: "constipation", step: .presence))
    }

    @Test func 첫_질문_답은_그대로_남기고_꼬리질문_답은_이어_붙인다() async {
        _ = engine.start()
        _ = await engine.handle(patientText: "그럭저럭이요")
        #expect(engine.ledger.conditionText == "그럭저럭이요")

        let other = InterviewEngine(config: config, rules: rules, analyzer: mock)
        _ = other.start()
        let followUp = await other.handle(patientText: "좀 피곤해요")
        #expect(followUp.utterance == config.openingFollowUp)
        _ = await other.handle(patientText: "잠을 잘 못 자서요")
        #expect(other.ledger.conditionText == "좀 피곤해요 / 잠을 잘 못 자서요")
    }

    @Test func 불명확하면_꼬리질문은_2회까지_후_검토필요로_넘어간다() async {
        _ = engine.start()
        _ = await engine.handle(patientText: "없어요") // opening (Mock: 언급 없음)
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .presence))

        let f1 = await engine.handle(patientText: "그냥 좀 그래요")
        #expect(f1.phase == .slot(key: "nausea_vomiting", step: .presence))
        #expect(f1.utterance == "조금 더 자세히 말씀해 주시겠어요?")
        let f2 = await engine.handle(patientText: "글쎄요")
        #expect(f2.phase == .slot(key: "nausea_vomiting", step: .presence))
        let moved = await engine.handle(patientText: "모르겠어요")

        #expect(moved.phase == .slot(key: "constipation", step: .presence))
        #expect(engine.ledger["nausea_vomiting"]?.followUps == 2)
        #expect(engine.ledger["nausea_vomiting"]?.needsReview == true)
    }

    @Test func 응급_키워드면_고정문구로_종료하고_플래그를_남긴다() async {
        _ = engine.start()
        let out = await engine.handle(patientText: "어제부터 숨이 차고 열이 39도까지 났어요")
        #expect(out.phase == .emergencyEnded)
        #expect(out.utterance == rules.message)
        #expect(mock.requests.isEmpty) // 키워드 규칙이 모델 호출보다 먼저

        let after = await engine.handle(patientText: "네")
        #expect(after.utterance.isEmpty && after.isFinished)
    }

    @Test func 모델_응급신호만_있어도_종료한다() async {
        var signal = TurnResult.empty
        signal.emergencySignal = true
        mock.script["몸이 너무 이상해요"] = signal
        _ = engine.start()
        let out = await engine.handle(patientText: "몸이 너무 이상해요")
        #expect(out.phase == .emergencyEnded)
        #expect(out.utterance == rules.message)
    }

    @Test func 모두_없음이면_7개를_한번씩_묻고_기타_요약_저장() async {
        _ = engine.start()
        var asked: [String] = []
        var out = InterviewEngine.Output(utterance: "", phase: engine.phase)
        for _ in 0..<40 where !out.isFinished {
            out = await engine.handle(patientText: "없어요")
            asked.append("AI: " + out.utterance)
        }
        #expect(out.phase == .saved)
        #expect(out.utterance == rules.closingMessage)
        for effect in config.effects {
            #expect(asked.filter { $0.hasSuffix(effect.ask) }.count == 1, "\(effect.id)")
        }
        #expect(asked.contains("AI: \(config.otherQuestion)"))
    }

    @Test func 부위는_환자가_말한_것만_기록한다() async {
        mock.script["손이 저려요"] = .mentions(Mention(effectId: "neuropathy", presence: .present,
                                                      locations: ["손", "발"]))
        _ = engine.start()
        _ = await engine.handle(patientText: "손이 저려요")
        #expect(engine.ledger["neuropathy"]?.locations == ["손"])
    }

    @Test func 부위_대상은_횟수_다음에_부위를_묻는다() async {
        mock.script["손발이 좀 저려요"] = .mentions(Mention(effectId: "neuropathy", presence: .present))
        _ = engine.start()
        _ = await engine.handle(patientText: "손발이 좀 저려요")
        while engine.phase != .slot(key: "neuropathy", step: .detail) {
            _ = await engine.handle(patientText: "없어요")
        }
        let out = await engine.handle(patientText: "어제부터요")
        #expect(out.phase == .slot(key: "neuropathy", step: .location))
        #expect(out.utterance == config.locationPrompt)
    }

    @Test func 번복하면_최신값으로_바꾸고_검토필요() async {
        mock.script["아까 토했어요"] = .mentions(Mention(effectId: "nausea_vomiting", presence: .present))
        _ = engine.start()
        _ = await engine.handle(patientText: "없어요")            // opening
        _ = await engine.handle(patientText: "구토는 없어요")       // nausea: absent
        #expect(engine.ledger["nausea_vomiting"]?.presence == .absent)
        _ = await engine.handle(patientText: "아까 토했어요")       // constipation 질문 중 번복
        #expect(engine.ledger["nausea_vomiting"]?.presence == .present)
        #expect(engine.ledger["nausea_vomiting"]?.needsReview == true)
        // 순서상 앞 항목이 미완이 되었으므로 횟수부터 묻는다
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .detail))
    }

    @Test func 기타_부작용은_한_번_더_묻고_답을_그대로_기록한_뒤_마무리() async {
        // 환자 말에 없는 이름("두통")은 쓰지 않고 발화 그대로 기록
        mock.script["머리가 아파요"] = .mentions(Mention(effectId: "other", otherName: "두통", presence: .present))
        _ = engine.start()
        while engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        let out = await engine.handle(patientText: "머리가 아파요")
        #expect(out.phase == .other && out.utterance == config.otherDetail.question)
        let summary = await engine.handle(patientText: "오후만 되면 지끈거려요")
        #expect(engine.ledger["other:머리가 아파요"]?.details.map(\.text) == ["오후만 되면 지끈거려요"])
        #expect(engine.phase == .saved)
        #expect(summary.utterance == config.otherDetail.recorded + " " + rules.closingMessage)
    }

    @Test func 그_밖에_네만_답하면_되묻고_그_답은_다시_묻지_않는다() async {
        mock.script["열이 조금 나요"] = .mentions(Mention(effectId: "other", otherName: "열", presence: .present))
        _ = engine.start()
        while engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        let ask = await engine.handle(patientText: "네")
        #expect(ask.phase == .other && ask.utterance == config.otherFollowUp)
        let summary = await engine.handle(patientText: "열이 조금 나요")
        #expect(engine.ledger["other:열"]?.presence == .present)
        #expect(engine.phase == .saved)
        #expect(summary.utterance.hasPrefix(config.otherDetail.recorded + " "))
    }

    @Test func 그_밖에_없다고_하면_바로_마무리() async {
        _ = engine.start()
        while engine.phase != .other { _ = await engine.handle(patientText: "없어요") }
        let out = await engine.handle(patientText: "없어요")
        #expect(engine.phase == .saved && out.utterance == rules.closingMessage)
    }

    @Test func 맞장구는_모델을_부를_답에만_차례로() async {
        _ = engine.start()
        #expect(engine.acknowledgement(for: "어제 좀 토했어요") == nil) // 첫 질문 답: 넘어가는 말과 겹침
        _ = await engine.handle(patientText: "없어요")
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .presence))
        #expect(engine.acknowledgement(for: "없어요") == nil) // 모델 없이 처리
        #expect(engine.acknowledgement(for: "숨이 차요") == nil) // 응급: 고정 안내
        let first = engine.acknowledgement(for: "속이 좀 이상했던 것 같기도 해요")
        let second = engine.acknowledgement(for: "속이 좀 이상했던 것 같기도 해요")
        #expect(first != nil && second != nil && first != second)
        #expect(engine.phase == .slot(key: "nausea_vomiting", step: .presence) && engine.ledger["nausea_vomiting"]?.presence == nil)
    }

    @Test func 모델_호출_실패는_세고_같은_질문을_다시_묻는다() async {
        mock.failOn = ["???"]
        _ = engine.start()
        _ = await engine.handle(patientText: "없어요")
        let out = await engine.handle(patientText: "???")
        #expect(mock.requests.filter { $0.patientText == "???" }.count == 1) // 취소 오류는 다시 분석하지 않는다
        #expect(out.phase == .slot(key: "nausea_vomiting", step: .presence))
        #expect(engine.ledger["nausea_vomiting"]?.followUps == 1)
    }
}

@MainActor
struct NumberWordTests {
    @Test(arguments: [
        ("한 6점 정도요", Set([6])),
        ("10점이요", Set([10])),
        ("0점", Set([0])),
        ("여섯 점", Set([6])),
        ("칠점이요", Set([7])),
        ("많이 아파요", Set<Int>()),
        ("열이 39도예요", Set<Int>()),
        ("이가 아파요", Set<Int>()),
        ("2~3점", Set([2, 3])),
    ])
    func 숫자만_인정(text: String, expected: Set<Int>) {
        #expect(NumberParser.numbers(in: text) == expected)
    }
}
